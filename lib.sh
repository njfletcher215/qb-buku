#!/usr/bin/env bash
# Shared helpers for qutebrowser userscripts

# Config defaults, overridden by $XDG_CONFIG_HOME/qb-buku/config.sh (or ~/.config/qb-buku/config.sh) if present
_default_dmenu_cmd=(rofi -dmenu -multi-select -i -p "bookmark")
DMENU_CMD=("${_default_dmenu_cmd[@]}")
AUTO_FETCH_TAGS=false
PYTHON=python3
DMENU_MSG_FLAG=""

qb_buku_config="${XDG_CONFIG_HOME:-$HOME/.config}/qb-buku/config.sh"
[[ -f "$qb_buku_config" ]] && source "$qb_buku_config"

# DMENU_MSG_FLAG's default (-mesg {message}, rofi's syntax) only applies when
# DMENU_CMD is also untouched -- a user-provided DMENU_CMD (e.g. plain dmenu,
# which has no message support) should not silently inherit a rofi-specific flag.
if [[ -z "$DMENU_MSG_FLAG" ]]; then
    _dmenu_cmd_is_default=true
    if [[ "${#DMENU_CMD[@]}" -eq "${#_default_dmenu_cmd[@]}" ]]; then
        for _i in "${!DMENU_CMD[@]}"; do
            [[ "${DMENU_CMD[$_i]}" == "${_default_dmenu_cmd[$_i]}" ]] || { _dmenu_cmd_is_default=false; break; }
        done
    else
        _dmenu_cmd_is_default=false
    fi
    [[ "$_dmenu_cmd_is_default" == true ]] && DMENU_MSG_FLAG="-mesg {message}"
    unset _dmenu_cmd_is_default _i
fi
unset _default_dmenu_cmd

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

# Fetches all bookmarks as "title\turl" lines and presents them via DMENU_CMD.
# Echoes selected lines, one per line. Exits 0 with no output if there are no
# bookmarks or the user cancels the picker.
pick_bookmarks() {
    require_jq
    local bookmarks
    bookmarks=$(buku --nostdin --print -j 2>/dev/null | \
        jq -r '.[] | "\(if .title != "" then .title else .uri end)\t\(.uri)"')
    if [[ -z "$bookmarks" ]]; then
        qute_error "No bookmarks found"
        exit 0
    fi
    echo "$bookmarks" | "${DMENU_CMD[@]}" || exit 0
}
