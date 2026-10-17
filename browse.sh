#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"

usage() {
    echo "Usage: $(basename "$0") [-t] [--dmenu-invocation <cmd>]" >&2
    echo "  -t                        open first result in a new tab (subsequent results always open in new tabs);" >&2
    echo "                            also enables multi-select in the picker, if DMENU_MULTI_FLAG is set" >&2
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


if [[ -z "${QUTE_FIFO:-}" ]]; then
    if ! command -v qutebrowser &>/dev/null; then
        qute_error "qutebrowser is required but not installed"
        exit 1
    fi
fi

if [[ "$new_tab" == true ]]; then
    selected=$(pick_bookmarks multi)
else
    selected=$(pick_bookmarks)
fi
if [[ -z "$selected" ]]; then
    qute_message "Cancelled"
    exit 0
fi

# Process each selected line. Inside qutebrowser, the first entry respects -t and all
# subsequent ones always open in a new tab. Outside qutebrowser, there's no "current
# tab" to reuse, so every entry opens in a new tab regardless of -t.
first=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    url=$(printf '%s' "$line" | awk -F'\t' '{print $NF}')

    if [[ -n "${QUTE_FIFO:-}" ]]; then
        if [[ "$first" == true ]]; then
            if [[ "$new_tab" == true ]]; then
                cmd="open -t $url"
            else
                cmd="open $url"
            fi
        else
            cmd="open -t $url"
        fi
        echo "$cmd" >> "$QUTE_FIFO"
    else
        env "${QUTEBROWSER_ENV[@]}" qutebrowser --target tab "${QUTEBROWSER_FLAGS[@]}" "$url" &
        disown
        # Give a freshly-launched instance's IPC socket a moment to come up
        # before firing off any further selections at it.
        [[ "$first" == true ]] && sleep 0.3
    fi
    first=false
done <<< "$selected"
