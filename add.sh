#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"

usage() {
    echo "Usage: $(basename "$0") [--auto-fetch-tags[=<true|false>]] [-q|--quiet] URL [--title <title>] [+|-] [tag, ...]" >&2
    echo "  --auto-fetch-tags[=<true|false>]  override AUTO_FETCH_TAGS for this invocation (bare flag means true)" >&2
    echo "  -q, --quiet                       skip the interactive title/tag prompts in qutebrowser mode" >&2
    echo "                                    (no effect when a URL is given explicitly)" >&2
    echo "  URL                               page to bookmark" >&2
    echo "  --title <title>                   set the bookmark's title" >&2
    echo "  +|-                               fetch tags from the page first, then merge (+) or remove (-) any given tags" >&2
    echo "  tag, ...                          comma-separated tags to add" >&2
    exit 1
}

quiet=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto-fetch-tags) AUTO_FETCH_TAGS=true; shift ;;
        --auto-fetch-tags=*) AUTO_FETCH_TAGS="${1#--auto-fetch-tags=}"; shift ;;
        -q|--quiet) quiet=true; shift ;;
        *) break ;;
    esac
done

is_qb_mode=false
if [[ $# -lt 1 ]]; then
    [[ -z "${QUTE_URL:-}" ]] && usage
    set -- "$QUTE_URL"
    is_qb_mode=true
fi

url="$1"
shift

if [[ ! "$url" =~ ^https?:// ]] && [[ ! "$url" =~ ^ftps?:// ]]; then
    qute_error "URL must begin with http://, https://, ftp://, or ftps://"; exit 1
fi

if [[ "$quiet" == true && "$is_qb_mode" == false ]]; then
    echo "Warning: -q/--quiet has no effect when a URL is given explicitly" >&2
fi

interactive=false
[[ "$is_qb_mode" == true && "$quiet" == false ]] && interactive=true

buku_args=("--add" "$url")

if [[ "$interactive" == true ]]; then
    mapfile -t preview < <("$PYTHON" "$here/fetch-preview.py" "$url")
    fetched_title="${preview[0]:-}"
    fetched_tags="${preview[1]:-}"

    title=$(printf '%s\n' "$fetched_title" | "${DMENU_CMD[@]}") || { qute_message "Cancelled"; exit 0; }

    included_tags=()
    if [[ "$AUTO_FETCH_TAGS" == true ]]; then
        while IFS= read -r -d '' tag; do included_tags+=("$tag"); done < <(split_tags "$fetched_tags")
        reminder="Auto-fetched tags: $fetched_tags"
    else
        if [[ -n "$fetched_tags" ]]; then
            tag_opts=()
            while IFS= read -r -d '' tag; do tag_opts+=("$tag"); done < <(split_tags "$fetched_tags")
            selected=$(printf '%s\n' "${tag_opts[@]}" | "${DMENU_CMD[@]}") || { qute_message "Cancelled"; exit 0; }
            while IFS= read -r line; do
                [[ -n "$line" ]] && included_tags+=("$line")
            done <<< "$selected"
        fi
        printf -v included_str '%s, ' "${included_tags[@]}"
        reminder="Selected tags: ${included_str%, }"
    fi

    msg_args=()
    while IFS= read -r -d '' word; do msg_args+=("$word"); done < <(dmenu_msg_flag_args "$reminder")
    extra_tags_str=$(printf '' | "${DMENU_CMD[@]}" "${msg_args[@]}") || { qute_message "Cancelled"; exit 0; }

    all_tags=("${included_tags[@]}")
    while IFS= read -r -d '' tag; do all_tags+=("$tag"); done < <(split_tags "$extra_tags_str")

    tags_str=""
    if [[ ${#all_tags[@]} -gt 0 ]]; then
        mapfile -t all_tags < <(printf '%s\n' "${all_tags[@]}" | sort -u)
        printf -v tags_str '%s, ' "${all_tags[@]}"
        tags_str="${tags_str%, }"
    fi

    buku_args+=("--title" "$title")
    [[ -n "$tags_str" ]] && buku_args+=("$tags_str")
else
    if [[ "${1:-}" == --title ]]; then
        [[ $# -lt 2 ]] && usage
        buku_args+=("--title" "$2")
        shift 2
    fi

    if [[ $# -gt 0 ]]; then
        case "$1" in
            +|-) buku_args+=("$1"); shift ;;
            *)   [[ "$AUTO_FETCH_TAGS" == true ]] && buku_args+=("+") ;;
        esac

        if [[ $# -gt 0 ]]; then
            printf -v tags_str '%s, ' "$@"
            tags_str="${tags_str%, }"
            buku_args+=("$tags_str")
        fi
    fi
fi

stderr_file=$(mktemp)
buku_exit_code=0
buku_stdout=$(buku --nostdin "${buku_args[@]}" 2>"$stderr_file") || buku_exit_code=$?
buku_stderr=$(cat "$stderr_file")
rm -f "$stderr_file"

if [[ $buku_exit_code -ne 0 ]]; then
    qute_error "Unknown error while adding $url"
elif [[ "$(strip_ansi "$buku_stderr")" =~ ^\[ERROR\] ]]; then
    qute_message "$url already exists"
else
    qute_message "Added $url"
fi

printf '%s\n' "$buku_stdout"
printf '%s\n' "$buku_stderr" >&2
