#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"
source "$here/config.sh"

usage() {
    echo "Usage: $(basename "$0") URL [+|-] [tag, ...]" >&2
    exit 1
}

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
