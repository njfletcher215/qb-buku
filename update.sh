#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"
source "$here/config.sh"

usage() {
    echo "Usage: $(basename "$0") [--python-invocation <path>] <id|URL> url <new-url>" >&2
    echo "       $(basename "$0") [--python-invocation <path>] <id|URL> title <new-title>" >&2
    echo "       $(basename "$0") [--python-invocation <path>] <id|URL> tags [+|-] <tag [tag ...]>" >&2
    echo "  --python-invocation <path>  override PYTHON for this invocation" >&2
    echo "  id|URL                      bookmark index or exact URL to update" >&2
    echo "  url <new-url>               set the bookmark's URL" >&2
    echo "  title <new-title>           set the bookmark's title" >&2
    echo "  tags [+|-] <tag [tag ...]>  set, append (+), or remove (-) tags" >&2
    exit 1
}

while [[ "${1:-}" == --python-invocation ]]; do
    [[ $# -lt 2 ]] && usage
    PYTHON="$2"
    shift 2
done

if [[ $# -lt 2 ]]; then
    usage
fi

id_or_url="$1"
field="$2"
shift 2

if [[ "$id_or_url" =~ ^https?:// ]] || [[ "$id_or_url" =~ ^ftps?:// ]]; then
    if ! id=$("$PYTHON" "$here/get-id-by-url.py" "$id_or_url" 2>&1); then
        qute_error "no bookmark found for URL '$id_or_url'"; exit 1
    fi
elif [[ "$id_or_url" =~ ^[0-9]+$ ]]; then
    id="$id_or_url"
else
    qute_error "first argument must be a URL or positive integer ID"; exit 1
fi

case "$field" in
    url)
        if [[ $# -ne 1 ]]; then
            qute_error "'url' requires exactly one additional argument (the new URL)"; exit 1
        fi
        new_url="$1"
        if [[ ! "$new_url" =~ ^https?:// ]] && [[ ! "$new_url" =~ ^ftps?:// ]]; then
            qute_error "new URL must begin with http://, https://, ftp://, or ftps://"; exit 1
        fi
        buku_args=("-u" "$id" "--url" "$new_url")
        ;;
    title)
        if [[ $# -ne 1 ]]; then
            qute_error "'title' requires exactly one additional argument (the new title)"; exit 1
        fi
        buku_args=("-u" "$id" "--title" "$1")
        ;;
    tags)
        buku_args=("-u" "$id" "--tag")
        modifier=""
        if [[ $# -gt 0 ]] && [[ "$1" == "+" || "$1" == "-" ]]; then
            modifier="$1"
            shift
        fi
        if [[ $# -lt 1 ]]; then
            qute_error "'tags' requires at least one tag argument"; exit 1
        fi
        printf -v tags_str '%s, ' "$@"
        tags_str="${tags_str%, }"
        [[ -n "$modifier" ]] && buku_args+=($modifier)
        buku_args+=("$tags_str")
        ;;
    *)
        qute_error "second argument must be 'url', 'title', or 'tags'"; exit 1
        ;;
esac

stderr_file=$(mktemp)
buku_exit_code=0
buku_stdout=$(buku --nostdin "${buku_args[@]}" 2>"$stderr_file") || buku_exit_code=$?
buku_stderr=$(cat "$stderr_file")
rm -f "$stderr_file"

if [[ $buku_exit_code -ne 0 ]]; then
    qute_error "Unknown error while updating $id_or_url"
else
    qute_message "Updated $id_or_url ($field)"
fi

printf '%s\n' "$buku_stdout"
printf '%s\n' "$buku_stderr" >&2
