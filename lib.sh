#!/usr/bin/env bash
# Shared helpers for qutebrowser userscripts

# Config defaults, overridden by $XDG_CONFIG_HOME/qb-buku/config.sh (or ~/.config/qb-buku/config.sh) if present
DMENU_CMD=(rofi -dmenu -multi-select -i -p "bookmark")
AUTO_FETCH_TAGS=false
PYTHON=python3

qb_buku_config="${XDG_CONFIG_HOME:-$HOME/.config}/qb-buku/config.sh"
[[ -f "$qb_buku_config" ]] && source "$qb_buku_config"

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

# Parses a dmenu invocation string (respecting quotes, no other shell expansion)
# into the DMENU_CMD array.
parse_dmenu_cmd() {
    DMENU_CMD=()
    while IFS= read -r -d '' word; do
        DMENU_CMD+=("$word")
    done < <(xargs printf '%s\0' <<< "$1")
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
