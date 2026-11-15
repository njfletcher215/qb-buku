#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"

usage() {
    echo "Usage: $(basename "$0") [--domain|--title] [--all] [-t] [-n <N>] [-q|--quiet]" >&2
    echo "       $(basename "$0")     [--dmenu-invocation <cmd>] [term, ...]" >&2
    echo "  --domain                  filter by URL (buku's ':' marker) instead of by tags" >&2
    echo "  --title                   filter by title (buku's '.' marker) instead of by tags" >&2
    echo "  --all                     only pick bookmarks matching all terms (default: any term)" >&2
    echo "  -t                        open the first pick in a new tab (later picks always open in new tabs;" >&2
    echo "                            outside qutebrowser, every pick opens in a new tab)" >&2
    echo "  -n <N>                    pick N distinct bookmarks (default: 1)" >&2
    echo "  -q, --quiet               skip the filter prompt (pick from every bookmark)" >&2
    echo "  --dmenu-invocation <cmd>  override DMENU_CMD for this invocation" >&2
    echo "  term, ...                 comma-separated tags, domains, or title words to filter by" >&2
    echo "                            (skips the filter prompt)" >&2
    exit 1
}

mode=tags
match=any
new_tab=false
count=1
quiet=false
args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain|--title)
            [[ "$mode" != tags ]] && usage
            mode="${1#--}"; shift
            ;;
        --all) match=all; shift ;;
        -t) new_tab=true; shift ;;
        -n)
            [[ $# -lt 2 ]] && usage
            count="$2"; shift 2
            ;;
        -q|--quiet) quiet=true; shift ;;
        --dmenu-invocation)
            [[ $# -lt 2 ]] && usage
            parse_dmenu_cmd "$2"
            shift 2
            ;;
        -h|--help) usage ;;
        --) shift; args+=("$@"); break ;;
        -*) usage ;;
        *) args+=("$1"); shift ;;
    esac
done

[[ "$count" =~ ^[1-9][0-9]*$ ]] || usage

is_qb_mode=false
[[ -n "${QUTE_FIFO:-}" ]] && is_qb_mode=true

if [[ "$is_qb_mode" == false ]]; then
    if ! command -v qutebrowser &>/dev/null; then
        qute_error "qutebrowser is required but not installed"
        exit 1
    fi
fi

require_jq

terms=()
if [[ ${#args[@]} -gt 0 ]]; then
    printf -v joined '%s ' "${args[@]}"
    while IFS= read -r -d '' term; do terms+=("$term"); done < <(split_tags "$joined")
elif [[ "$quiet" == false ]]; then
    msg_args=()
    while IFS= read -r -d '' word; do msg_args+=("$word"); done < <(dmenu_msg_flag_args "Random bookmark: $mode (match $match)")

    if [[ "$mode" == tags ]]; then
        multi_args=()
        while IFS= read -r -d '' word; do multi_args+=("$word"); done < <(dmenu_multi_flag_args)
        mapfile -t all_tags < <(list_all_tags)
        answer=$(dmenu_entries "${all_tags[@]}" | "${DMENU_CMD[@]}" "${multi_args[@]}" "${msg_args[@]}") || { qute_message "Cancelled"; exit 0; }
    else
        answer=$(printf '' | "${DMENU_CMD[@]}" "${msg_args[@]}") || { qute_message "Cancelled"; exit 0; }
    fi

    # Each line is either a picked tag or typed (possibly comma-separated) text.
    while IFS= read -r line; do
        while IFS= read -r -d '' term; do terms+=("$term"); done < <(split_tags "$line")
    done <<< "$answer"
fi

if [[ ${#terms[@]} -eq 0 ]]; then
    buku_args=(--print)
elif [[ "$mode" == tags ]]; then
    sep=", "
    [[ "$match" == all ]] && sep=" + "
    printf -v tags_str "%s$sep" "${terms[@]}"
    buku_args=(--stag "${tags_str%"$sep"}")
else
    marker=":"
    [[ "$mode" == title ]] && marker="."
    # The keywords must directly follow --sany/--sall, or buku sees none of them.
    buku_args=("--s$match" "${terms[@]/#/$marker}" --markers)
fi

# buku prints a lone object rather than a one-element array when there's a single result.
urls=()
while IFS= read -r -d '' url; do
    urls+=("$url")
done < <(buku --nostdin "${buku_args[@]}" --random "$count" -j 2>/dev/null | jq -j '
    if type == "object" then [.] else . end
    | .[]
    | "\(.uri)\u0000"
')

if [[ ${#urls[@]} -eq 0 ]]; then
    qute_error "No matching bookmarks found"; exit 1
fi

# Inside qutebrowser, the first pick respects -t and all subsequent ones always open
# in a new tab. Outside qutebrowser, there's no "current tab" to reuse, so every pick
# opens in a new tab regardless of -t.
for i in "${!urls[@]}"; do
    if [[ "$is_qb_mode" == true ]]; then
        if [[ $i -eq 0 && "$new_tab" == false ]]; then
            echo "open ${urls[$i]}" >> "$QUTE_FIFO"
        else
            echo "open -t ${urls[$i]}" >> "$QUTE_FIFO"
        fi
    else
        env "${QUTEBROWSER_ENV[@]}" qutebrowser --target tab "${QUTEBROWSER_FLAGS[@]}" "${urls[$i]}" &
        disown
        # Give a freshly-launched instance's IPC socket a moment to come up
        # before firing off any further picks at it.
        [[ $i -eq 0 ]] && sleep 0.3
    fi
done
qute_message "Opened ${#urls[@]} random bookmark(s)"
