#!/usr/bin/env bash
#
# At least one argument is required; omitting all would delete every bookmark (and is thus blocked)

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"
source "$here/config.sh"

usage() {
    echo "Usage: $(basename "$0") [--python-invocation <path>] <index [index ...]|range|URL ...>" >&2
    echo "  --python-invocation <path>  override PYTHON for this invocation" >&2
    echo "  index                       one or more positive integers" >&2
    echo "  range                       a single range in the form N-M (e.g. 3-7)" >&2
    echo "  URL                         exact URL to look up and delete" >&2
    exit 1
}

while [[ "${1:-}" == --python-invocation ]]; do
    [[ $# -lt 2 ]] && usage
    PYTHON="$2"
    shift 2
done

if [[ $# -lt 1 ]]; then
    [[ -z "${QUTE_URL:-}" ]] && usage
    set -- "$QUTE_URL"
fi

successes=()
failures=()
indices=()
id_fetch_failures=()

for arg in "$@"; do
    if [[ "$arg" =~ ^https?:// ]] || [[ "$arg" =~ ^ftps?:// ]]; then
        if id=$("$PYTHON" "$here/get-id-by-url.py" "$arg" 2>&1); then
            indices+=("$id")
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
            successes+=("${BASH_REMATCH[1]}")
        fi
    done < <(buku --nostdin --tacit --delete "${indices[@]}" 2>"$stderr_file" || buku_exit_code=$?)
    while IFS= read -r line; do
        buku_stderr+=("$line")
        if [[ "$(echo "$line" | strip_ansi)" =~ \[ERROR\]\ No\ matching\ index\ ([0-9]+) ]]; then
            failures+=("${BASH_REMATCH[1]}")
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
