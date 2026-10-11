#!/usr/bin/env bash
#
# At least one argument is required; omitting all would delete every bookmark (and is thus blocked)

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"

usage() {
    echo "Usage: $(basename "$0") [--python-invocation <path>] [-d|--use-dmenu] [--dmenu-invocation <cmd>] <index [index ...]|range|URL ...>" >&2
    echo "  --python-invocation <path>  override PYTHON for this invocation" >&2
    echo "  -d, --use-dmenu             pick bookmarks to delete via the dmenu-style picker" >&2
    echo "  --dmenu-invocation <cmd>    override DMENU_CMD for this invocation" >&2
    echo "  index                       one or more positive integers" >&2
    echo "  range                       a single range in the form N-M (e.g. 3-7)" >&2
    echo "  URL                         exact URL to look up and delete" >&2
    exit 1
}

use_dmenu=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --python-invocation)
            [[ $# -lt 2 ]] && usage
            PYTHON="$2"
            shift 2
            ;;
        --dmenu-invocation)
            [[ $# -lt 2 ]] && usage
            parse_dmenu_cmd "$2"
            shift 2
            ;;
        -d|--use-dmenu) use_dmenu=true; shift ;;
        -h|--help) usage ;;
        -*) usage ;;
        *) break ;;
    esac
done

if [[ $# -lt 1 ]]; then
    if [[ "$use_dmenu" == true ]]; then
        selected=$(pick_bookmarks)
        [[ -z "$selected" ]] && exit 0
        urls=()
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            urls+=("$(printf '%s' "$line" | awk -F'\t' '{print $NF}')")
        done <<< "$selected"
        set -- "${urls[@]}"
    elif [[ -n "${QUTE_URL:-}" ]]; then
        set -- "$QUTE_URL"
    else
        usage
    fi
fi

successes=()
failures=()
indices=()
id_fetch_failures=()
declare -A id_to_url=()

for arg in "$@"; do
    if [[ "$arg" =~ ^https?:// ]] || [[ "$arg" =~ ^ftps?:// ]]; then
        if id=$("$PYTHON" "$here/get-id-by-url.py" "$arg" 2>&1); then
            indices+=("$id")
            id_to_url["$id"]="$arg"
        else
            id_fetch_failures+=("'$arg'")
        fi
    elif [[ "$arg" =~ ^[0-9]+-[0-9]+$ ]]; then
        indices+=("$arg")
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
        indices+=("$arg")
    else
        qute_error "invalid argument '${arg}' — expected a URL, positive integer, or N-M range"; exit 1
    fi
done

buku_stdout=()
buku_stderr=()
buku_exit_code=0

if [[ ${#indices[@]} -gt 0 ]]; then
    stderr_file=$(mktemp)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        buku_stdout+=("$line")
        if [[ "$line" =~ ^Index\ ([0-9]+)\ deleted ]]; then
            idx="${BASH_REMATCH[1]}"
            successes+=("${id_to_url[$idx]:-$idx}")
        fi
    done < <(buku --nostdin --tacit --delete "${indices[@]}" 2>"$stderr_file" || buku_exit_code=$?)
    while IFS= read -r line; do
        buku_stderr+=("$line")
        if [[ "$(strip_ansi "$line")" =~ \[ERROR\]\ No\ matching\ index\ ([0-9]+) ]]; then
            idx="${BASH_REMATCH[1]}"
            failures+=("${id_to_url[$idx]:-$idx}")
        fi
    done < "$stderr_file"
    rm -f "$stderr_file"
fi

if [[ $buku_exit_code -ne 0 ]]; then
    qute_error "Unknown error while removing ${indices[*]}"
fi
if [[ ${#successes[@]} -gt 0 ]]; then
    qute_message "Removed ${successes[*]}"
fi
if [[ ${#failures[@]} -gt 0 ]]; then
    qute_message "${failures[*]} was not found"
fi
if [[ ${#id_fetch_failures[@]} -gt 0 ]]; then
    qute_message "${id_fetch_failures[*]} was not found"
fi

printf '%s\n' "${buku_stdout[@]}"
printf '%s\n' "${buku_stderr[@]}" >&2
