#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"

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
            parse_dmenu_cmd "$2"
            shift 2
            ;;
        -h|--help) usage ;;
        *) usage ;;
    esac
done


selected=$(pick_bookmarks)
if [[ -z "$selected" ]]; then
    qute_message "Cancelled"
    exit 0
fi

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
