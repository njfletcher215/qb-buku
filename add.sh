#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"
source "$here/config.sh"

usage() {
    echo "Usage: $(basename "$0") [--auto-fetch-tags[=<true|false>]] URL [+|-] [tag, ...]" >&2
    echo "  --auto-fetch-tags[=<true|false>]  override AUTO_FETCH_TAGS for this invocation (bare flag means true)" >&2
    echo "  URL                               page to bookmark" >&2
    echo "  +|-                               fetch tags from the page first, then merge (+) or remove (-) any given tags" >&2
    echo "  tag, ...                          comma-separated tags to add" >&2
    exit 1
}

while [[ "${1:-}" == --auto-fetch-tags || "${1:-}" == --auto-fetch-tags=* ]]; do
    case "$1" in
        --auto-fetch-tags) AUTO_FETCH_TAGS=true ;;
        --auto-fetch-tags=*) AUTO_FETCH_TAGS="${1#--auto-fetch-tags=}" ;;
    esac
    shift
done

if [[ $# -lt 1 ]]; then
    [[ -z "${QUTE_URL:-}" ]] && usage
    set -- "$QUTE_URL"
fi

url="$1"
shift

if [[ ! "$url" =~ ^https?:// ]] && [[ ! "$url" =~ ^ftps?:// ]]; then
    qute_error "URL must begin with http://, https://, ftp://, or ftps://"; exit 1
fi

buku_args=("--add" "$url")

if [[ $# -gt 0 ]]; then
    case "$1" in
        +|-) buku_args+=("$1"); shift ;;
        *)   [[ "${AUTO_FETCH_TAGS:-false}" == true ]] && buku_args+=("+") ;;
    esac

    if [[ $# -gt 0 ]]; then
        printf -v tags_str '%s, ' "$@"
        tags_str="${tags_str%, }"
        buku_args+=("$tags_str")
    fi
fi

stderr_file=$(mktemp)
buku_exit_code=0
buku_stdout=$(buku --nostdin "${buku_args[@]}" 2>"$stderr_file") || buku_exit_code=$?
buku_stderr=$(cat "$stderr_file")
rm -f "$stderr_file"

if [[ $buku_exit_code -ne 0 ]]; then
    qute_error "Unknown error while adding $url"
elif [[ "$(echo "$buku_stderr" | strip_ansi)" =~ ^\[ERROR\] ]]; then
    qute_message "$url already exists"
else
    qute_message "Added $url"
fi

printf '%s\n' "$buku_stdout"
printf '%s\n' "$buku_stderr" >&2
