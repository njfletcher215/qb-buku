#!/usr/bin/env bash
# Shared helpers for qutebrowser userscripts

# Config defaults, overridden by $XDG_CONFIG_HOME/qb-buku/config.sh (or ~/.config/qb-buku/config.sh) if present
_default_dmenu_cmd=(rofi -dmenu -i -p "bookmark" -markup-rows -sep $'\x1f' -eh 3)
DMENU_CMD=("${_default_dmenu_cmd[@]}")
AUTO_FETCH_TAGS=false
PYTHON=python3
DMENU_MSG_FLAG=""
DMENU_MULTI_FLAG=""
ESCAPE_PANGO=true
BOOKMARK_FORMAT=""
QUTEBROWSER_FLAGS=()
QUTEBROWSER_ENV=()

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

# DMENU_MULTI_FLAG's default (-multi-select, rofi's syntax) only applies when
# DMENU_CMD is also untouched -- a user-provided DMENU_CMD (e.g. plain dmenu,
# which has no multi-select support unless patched) should not silently inherit
# a rofi-specific flag.
if [[ -z "$DMENU_MULTI_FLAG" && "$_dmenu_cmd_is_default" == true ]]; then
    DMENU_MULTI_FLAG="-multi-select"
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

# Requires the Python yq (https://github.com/kislyuk/yq), a jq wrapper for YAML --
# not the unrelated Go yq of the same name, which uses a different syntax.
require_yq() {
    require_jq
    if ! command -v yq &>/dev/null; then
        qute_error "yq is required but not installed"
        exit 1
    fi
    if ! yq --help 2>&1 | grep -q 'jq filter'; then
        qute_error "yq must be the Python yq (kislyuk/yq), not the Go yq (mikefarah/yq)"
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

# Builds the dmenu multi-select-flag arguments by splitting DMENU_MULTI_FLAG into
# words. Does nothing if DMENU_MULTI_FLAG is empty.
dmenu_multi_flag_args() {
    [[ -z "${DMENU_MULTI_FLAG:-}" ]] && return 0
    split_words "$DMENU_MULTI_FLAG"
}

# Prints each argument as one picker entry, terminated by the entry separator
# BOOKMARK_FORMAT ends in (see pick_bookmarks()), so lists split into entries the
# same way bookmarks do. Prints nothing if given no arguments.
dmenu_entries() {
    local sep="${BOOKMARK_FORMAT: -1}" entry
    for entry in "$@"; do
        printf '%s%s' "$entry" "$sep"
    done
}

# Prints every tag in use across all bookmarks (buku --stag's tag list), one per line.
list_all_tags() {
    local line
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*[0-9]+\.[[:space:]]+(.*)[[:space:]]\([0-9]+\)$ ]] && printf '%s\n' "${BASH_REMATCH[1]}"
    done < <(buku --nostdin --stag </dev/null 2>/dev/null)
    return 0
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

# Helpers for the user-defined add_additional_tags hook
# Inside the hook, BOOKMARK_URL, BOOKMARK_TITLE, BOOKMARK_DOMAIN and the
# BOOKMARK_TAGS array describe the bookmark as buku stored it.
_hook_tags() {
    local IFS=' '
    split_tags "$*"
}

# True if TAG (a single tag) is in BOOKMARK_TAGS (case-insensitive).
_hook_has_one_tag() {
    local existing
    for existing in "${BOOKMARK_TAGS[@]}"; do
        [[ "${existing,,}" == "${1,,}" ]] && return 0
    done
    return 1
}

# Appends each comma-separated TAG (lowercased) to BOOKMARK_TAGS unless already present.
add_tag() {
    local tag
    while IFS= read -r -d '' tag; do
        _hook_has_one_tag "$tag" || BOOKMARK_TAGS+=("${tag,,}")
    done < <(_hook_tags "$@")
}

# True if every comma-separated TAG is in BOOKMARK_TAGS (case-insensitive).
has_tag() {
    local tag
    while IFS= read -r -d '' tag; do
        _hook_has_one_tag "$tag" || return 1
    done < <(_hook_tags "$@")
}

# True if any comma-separated TAG is in BOOKMARK_TAGS (case-insensitive).
has_any_tag() {
    local tag
    while IFS= read -r -d '' tag; do
        _hook_has_one_tag "$tag" && return 0
    done < <(_hook_tags "$@")
    return 1
}

# True if BOOKMARK_DOMAIN is any DOMAIN or a subdomain of one
# (youtube.com matches www.youtube.com, but not notyoutube.com).
domain_is() {
    local domain
    for domain in "$@"; do
        domain="${domain,,}"
        [[ "$BOOKMARK_DOMAIN" == "$domain" || "$BOOKMARK_DOMAIN" == *".$domain" ]] && return 0
    done
    return 1
}

# Runs the add_additional_tags hook against a bookmark's URL, TITLE and TAGS_STR
# (as stored by buku), without touching the DB. Prints the tags it added,
# ", "-joined, or nothing if it added none.
_run_additional_tags_hook() {
    local url="$1" title="$2" tags_str="$3"

    local -a original_tags=() final_tags=() new_tags=()
    local tag
    while IFS= read -r -d '' tag; do original_tags+=("${tag,,}"); done < <(split_tags "$tags_str")

    while IFS= read -r -d '' tag; do final_tags+=("$tag"); done < <(
        set +euo pipefail
        BOOKMARK_URL="$url"
        BOOKMARK_TITLE="$title"
        BOOKMARK_DOMAIN="${url#*://}"
        BOOKMARK_DOMAIN="${BOOKMARK_DOMAIN%%[/?#]*}"
        BOOKMARK_DOMAIN="${BOOKMARK_DOMAIN##*@}"
        BOOKMARK_DOMAIN="${BOOKMARK_DOMAIN%:*}"
        BOOKMARK_DOMAIN="${BOOKMARK_DOMAIN,,}"
        BOOKMARK_TAGS=("${original_tags[@]}")
        add_additional_tags >&2
        printf '%s\0' "${BOOKMARK_TAGS[@]}"
    )

    local -A is_original=()
    for tag in "${original_tags[@]}"; do is_original["$tag"]=1; done
    for tag in "${final_tags[@]}"; do
        [[ -z "${is_original[$tag]:-}" ]] && new_tags+=("$tag")
    done
    [[ ${#new_tags[@]} -eq 0 ]] && return 0

    local new_str
    printf -v new_str '%s, ' "${new_tags[@]}"
    printf '%s\n' "${new_str%, }"
}

# Runs the add_additional_tags hook, if the config defines one, against the stored
# bookmark for URL, then appends any tags it added.
apply_additional_tags() {
    declare -F add_additional_tags &>/dev/null || return 0

    local url="$1" id bookmark_json title tags_str new_str
    require_jq
    if ! id=$("$PYTHON" "$here/get-id-by-url.py" "$url" 2>/dev/null); then
        echo "Warning: couldn't look up $url to apply add_additional_tags" >&2
        return 0
    fi
    bookmark_json=$(buku --nostdin --print "$id" -j 2>/dev/null) || bookmark_json=""
    if [[ -z "$bookmark_json" ]]; then
        echo "Warning: couldn't read bookmark $id to apply add_additional_tags" >&2
        return 0
    fi
    title=$(jq -r '.title // ""' <<< "$bookmark_json")
    tags_str=$(jq -r '.tags // ""' <<< "$bookmark_json")

    new_str=$(_run_additional_tags_hook "$url" "$title" "$tags_str")
    [[ -z "$new_str" ]] && return 0

    if ! buku --nostdin -u "$id" --tag + "$new_str" >/dev/null 2>&1; then
        echo "Warning: couldn't add tags '$new_str' to $url" >&2
        return 0
    fi
    printf '%s\n' "$new_str"
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
# Pass "multi" to additionally apply DMENU_MULTI_FLAG, enabling multi-select.
# Exits 0 with no output if there are no bookmarks or the user cancels the picker.
pick_bookmarks() {
    local multi=false
    [[ "${1:-}" == multi ]] && multi=true

    require_jq
    local json
    json=$(buku --nostdin --print -j 2>/dev/null)
    if [[ -z "$json" || "$json" == "[]" ]]; then
        qute_error "No bookmarks found"
        exit 0
    fi

    local escape=false
    [[ "$ESCAPE_PANGO" == true ]] && escape=true

    # Avoid colliding with a dmenu separator the user may have chosen
    local field_sep=$'\x1e'
    [[ "${DMENU_CMD[*]}" == *$'\x1e'* ]] && field_sep=$'\x1f'

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

    local -a multi_args=()
    if [[ "$multi" == true ]]; then
        while IFS= read -r -d '' word; do multi_args+=("$word"); done < <(dmenu_multi_flag_args)
    fi

    local result
    result=$(printf '%s' "$joined" | "${DMENU_CMD[@]}" "${multi_args[@]}") || exit 0
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
