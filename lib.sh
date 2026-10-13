#!/usr/bin/env bash
# Shared helpers for qutebrowser userscripts

# Config defaults, overridden by $XDG_CONFIG_HOME/qb-buku/config.sh (or ~/.config/qb-buku/config.sh) if present
_default_dmenu_cmd=(rofi -dmenu -multi-select -i -p "bookmark" -markup-rows -sep $'\x1f' -eh 3)
DMENU_CMD=("${_default_dmenu_cmd[@]}")
AUTO_FETCH_TAGS=false
PYTHON=python3
DMENU_MSG_FLAG=""
ESCAPE_PANGO=true
BOOKMARK_FORMAT=""

qb_buku_config="${XDG_CONFIG_HOME:-$HOME/.config}/qb-buku/config.sh"
[[ -f "$qb_buku_config" ]] && source "$qb_buku_config"

_dmenu_cmd_is_default=true
if [[ "${#DMENU_CMD[@]}" -eq "${#_default_dmenu_cmd[@]}" ]]; then
    for _i in "${!DMENU_CMD[@]}"; do
        [[ "${DMENU_CMD[$_i]}" == "${_default_dmenu_cmd[$_i]}" ]] || { _dmenu_cmd_is_default=false; break; }
    done
else
    _dmenu_cmd_is_default=false
fi
unset _i _default_dmenu_cmd

# DMENU_MSG_FLAG's default (-mesg {message}, rofi's syntax) only applies when
# DMENU_CMD is also untouched -- a user-provided DMENU_CMD (e.g. plain dmenu,
# which has no message support) should not silently inherit a rofi-specific flag.
if [[ -z "$DMENU_MSG_FLAG" && "$_dmenu_cmd_is_default" == true ]]; then
    DMENU_MSG_FLAG="-mesg {message}"
fi

# BOOKMARK_FORMAT's styled default (Pango markup) only applies when DMENU_CMD is
# also untouched Otherwise it falls back to the plain "{title}\t{url}" layout.
#
# Both end in their own trailing separator character (see pick_bookmarks()):
# the styled one in the same -sep byte the default DMENU_CMD is configured with,
# the plain one in a plain newline, matching the standard dmenu row separator.
if [[ -z "$BOOKMARK_FORMAT" ]]; then
    if [[ "$_dmenu_cmd_is_default" == true ]]; then
        BOOKMARK_FORMAT=$'{title}\n<span foreground="#888888">{url}</span>\n<span foreground="#888888" size="small"><i>{tags}</i></span>\x1f'
    else
        BOOKMARK_FORMAT=$'{title}\t{url}\n'
    fi
fi

strip_ansi() { printf '%s' "$1" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'; }

qute_error() {
    local msg="$1"
    if [[ -n "${QUTE_FIFO:-}" ]]; then
        printf "message-error \"%s, see ':process $$' for details\"\n" "$(strip_ansi "$msg")" >> "$QUTE_FIFO"
    fi
    echo "Error: $msg" >&2
}

qute_message() {
    local msg="$1"
    if [[ -n "${QUTE_FIFO:-}" ]]; then
        printf "message-info \"%s, see ':process $$' for details\"\n" "$(strip_ansi "$msg")" >> "$QUTE_FIFO"
    else
        echo "$msg"
    fi
}

require_jq() {
    if ! command -v jq &>/dev/null; then
        qute_error "jq is required but not installed"
        exit 1
    fi
}

split_words() {
    xargs printf '%s\0' <<< "$1"
}

# Parses a dmenu invocation string (respecting quotes, no other shell expansion)
# into the DMENU_CMD array.
parse_dmenu_cmd() {
    DMENU_CMD=()
    while IFS= read -r -d '' word; do
        DMENU_CMD+=("$word")
    done < <(split_words "$1")
}

# Builds the dmenu message-flag arguments for MESSAGE by splitting
# DMENU_MSG_FLAG into words and substituting the literal token '{message}'
# within each word for MESSAGE.
# Does nothing if DMENU_MSG_FLAG is empty.
dmenu_msg_flag_args() {
    local message="$1"
    [[ -z "${DMENU_MSG_FLAG:-}" ]] && return 0
    local word
    while IFS= read -r -d '' word; do
        printf '%s\0' "${word//\{message\}/$message}"
    done < <(split_words "$DMENU_MSG_FLAG")
}

# Splits TAGSTRING on ',' and
# trims leading/trailing whitespace from each piece
split_tags() {
    local str="$1" tag
    local -a parts
    IFS=',' read -ra parts <<< "$str"
    for tag in "${parts[@]}"; do
        tag="${tag#"${tag%%[![:space:]]*}"}"
        tag="${tag%"${tag##*[![:space:]]}"}"
        [[ -n "$tag" ]] && printf '%s\0' "$tag"
    done
}

# Number of physical lines one rendered BOOKMARK_FORMAT entry occupies, used to
# split multi-selected picker output back into one chunk per entry. BOOKMARK_FORMAT
# is expected to end in its own trailing separator character (see pick_bookmarks()),
# which isn't itself a display line, so it's excluded before counting.
_bookmark_format_line_count() {
    local without_sep="${1%?}"
    local no_newlines="${without_sep//[^$'\n']/}"
    echo $(( ${#no_newlines} + 1 ))
}

# binds $title/$url/$tags/$id for each bookmark object in the input array.
_bookmark_format_bindings='
    .[] as $b |
    (if $b.title != "" then $b.title else $b.uri end | gsub("\n";" ")) as $title |
    ($b.uri | gsub("\n";" ")) as $url |
    ([$b.tags // "" | split(",")[] | gsub("^\\s+|\\s+$";"")] | map(select(length>0)) | join(", ") | gsub("\n";" ")) as $tags |
    ($b.index|tostring) as $id |
'

# Fetches all bookmarks and presents them via DMENU_CMD.
# Exits 0 with no output if there are no bookmarks or the user cancels the picker.
pick_bookmarks() {
    require_jq
    local json
    json=$(buku --nostdin --print -j 2>/dev/null)
    if [[ -z "$json" || "$json" == "[]" ]]; then
        qute_error "No bookmarks found"
        exit 0
    fi

    local escape=false
    [[ "$ESCAPE_PANGO" == true ]] && escape=true

    local field_sep=$'\x1e'

    local -a entries=() plain_titles=() plain_urls=()
    while IFS= read -r -d "$field_sep" rendered && IFS= read -r -d "$field_sep" title && IFS= read -r -d "$field_sep" url; do
        entries+=("$rendered")
        plain_titles+=("$title")
        plain_urls+=("$url")
    done < <(jq -j --arg fmt "$BOOKMARK_FORMAT" --argjson escape "$escape" --arg sep "$field_sep" "$_bookmark_format_bindings"'
        (if $escape then
            ($title | gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;"))
         else $title end) as $vtitle |
        (if $escape then
            ($url | gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;"))
         else $url end) as $vurl |
        (if $escape then
            ($tags | gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;"))
         else $tags end) as $vtags |
        ($fmt
            | gsub("\\{title\\}"; $vtitle)
            | gsub("\\{url\\}"; $vurl)
            | gsub("\\{tags\\}"; $vtags)
            | gsub("\\{id\\}"; $id)
        ) as $rendered |
        "\($rendered)\($sep)\($title)\($sep)\($url)\($sep)"
    ' <<< "$json")

    if [[ ${#entries[@]} -eq 0 ]]; then
        qute_error "No bookmarks found"
        exit 0
    fi

    local n_lines
    n_lines=$(_bookmark_format_line_count "$BOOKMARK_FORMAT")

    local joined
    joined=$(printf '%s' "${entries[@]}")

    local result
    result=$(printf '%s' "$joined" | "${DMENU_CMD[@]}") || exit 0
    [[ -z "$result" ]] && return

    local -A entry_to_index=()
    local i
    for i in "${!entries[@]}"; do
        entry_to_index["${entries[$i]%?}"]="$i"
    done

    local -a result_lines=()
    mapfile -t result_lines <<< "$result"

    local total=${#result_lines[@]}
    if (( total % n_lines != 0 )); then
        qute_error "Picker output didn't match BOOKMARK_FORMAT's line count -- is DMENU_CMD's -sep (or equivalent) set up correctly?"
        exit 1
    fi

    local start chunk idx
    for ((start = 0; start < total; start += n_lines)); do
        chunk=$(printf '%s\n' "${result_lines[@]:start:n_lines}")
        chunk="${chunk%$'\n'}"
        idx="${entry_to_index[$chunk]:-}"
        if [[ -z "$idx" ]]; then
            qute_error "Could not match a selected entry back to a bookmark"
            continue
        fi
        printf '%s\t%s\n' "${plain_titles[$idx]}" "${plain_urls[$idx]}"
    done
}
