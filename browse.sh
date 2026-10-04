#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"
source "$here/config.sh"

usage() {
    echo "Usage: $(basename "$0") [-t] [--dmenu-invocation <cmd>]" >&2
    echo "  -t                        open first result in a new tab (subsequent results always open in new tabs)" >&2
    echo "  --dmenu-invocation <cmd>  override DMENU_CMD for this invocation" >&2
    exit 1
}

new_tab=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t) new_tab=true; shift ;;
        --dmenu-invocation)
            [[ $# -lt 2 ]] && usage
            # split on whitespace, respecting quotes (but not performing any other shell expansion)
            DMENU_CMD=()
            while IFS= read -r -d '' word; do
                DMENU_CMD+=("$word")
            done < <(xargs printf '%s\0' <<< "$2")
            shift 2
            ;;
        -h|--help) usage ;;
        *) usage ;;
    esac
done


if ! command -v jq &>/dev/null; then
    qute_error "jq is required but not installed"
    exit 1
fi

# Fetch bookmarks as tab-separated "title\turl" lines.
# Title comes first so dmenu searches by title naturally; URL follows for extraction.
bookmarks=$(buku --nostdin --print -j 2>/dev/null | \
    jq -r '.[] | "\(if .title != "" then .title else .uri end)\t\(.uri)"')

if [[ -z "$bookmarks" ]]; then
    qute_error "No bookmarks found"
    exit 0
fi

# Present to dmenu; exit cleanly if the user cancels (empty selection or non-zero exit)
selected=$(echo "$bookmarks" | "${DMENU_CMD[@]}") || exit 0
[[ -z "$selected" ]] && exit 0

# Process each selected line. First entry respects -t; all subsequent always open in a new tab.
first=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    url=$(printf '%s' "$line" | awk -F'\t' '{print $NF}')

    if [[ "$first" == true ]]; then
        first=false
        if [[ "$new_tab" == true ]]; then
            cmd="open -t $url"
        else
            cmd="open $url"
        fi
    else
        cmd="open -t $url"
    fi

    if [[ -n "${QUTE_FIFO:-}" ]]; then
        echo "$cmd" >> "$QUTE_FIFO"
    else
        echo "$url"
    fi
done <<< "$selected"
