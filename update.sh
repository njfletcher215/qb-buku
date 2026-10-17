#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"

usage() {
    echo "Usage: $(basename "$0") [--python-invocation <path>] <id|URL> url <new-url>" >&2
    echo "       $(basename "$0") [--python-invocation <path>] <id|URL> title <new-title>" >&2
    echo "       $(basename "$0") [--python-invocation <path>] <id|URL> tags [+|-] <tag [tag ...]>" >&2
    echo "       $(basename "$0") [--python-invocation <path>] -d|--use-dmenu [--dmenu-invocation <cmd>] [<id|URL>]" >&2
    echo "  --python-invocation <path>  override PYTHON for this invocation" >&2
    echo "  id|URL                      bookmark index or exact URL to update" >&2
    echo "  url <new-url>               set the bookmark's URL" >&2
    echo "  title <new-title>           set the bookmark's title" >&2
    echo "  tags [+|-] <tag [tag ...]>  set, append (+), or remove (-) tags" >&2
    echo "  -d, --use-dmenu             interactively set title and tags via dmenu picker" >&2
    echo "                              (picks a bookmark via DMENU_CMD first, unless <id|URL> is given)" >&2
    echo "  --dmenu-invocation <cmd>    override DMENU_CMD for this invocation" >&2
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
        *) break ;;
    esac
done

if [[ "$use_dmenu" == true ]]; then
    if [[ $# -gt 1 ]]; then
        usage
    fi

    if [[ $# -eq 1 ]]; then
        id_or_url="$1"
    else
        selected=$(pick_bookmarks)
        if [[ -z "$selected" ]]; then
            qute_message "Cancelled"
            exit 0
        fi
        id_or_url=$(head -n1 <<< "$selected" | awk -F'\t' '{print $NF}')
    fi

    if [[ "$id_or_url" =~ ^https?:// ]] || [[ "$id_or_url" =~ ^ftps?:// ]]; then
        if ! id=$("$PYTHON" "$here/get-id-by-url.py" "$id_or_url" 2>&1); then
            qute_error "no bookmark found for URL '$id_or_url'"; exit 1
        fi
    elif [[ "$id_or_url" =~ ^[0-9]+$ ]]; then
        id="$id_or_url"
    else
        qute_error "first argument must be a URL or positive integer ID"; exit 1
    fi

    require_jq
    bookmark_json=$(buku --nostdin --print "$id" -j 2>/dev/null)
    if [[ -z "$bookmark_json" ]]; then
        qute_error "no bookmark found for id '$id'"; exit 1
    fi
    current_title=$(jq -r '.title' <<< "$bookmark_json")
    current_tags_str=$(jq -r '.tags' <<< "$bookmark_json")

    # Step 1: title, pre-populated with (and defaulting to) the current title.
    new_title=$(printf '%s\n' "$current_title" | "${DMENU_CMD[@]}") || { qute_message "Cancelled"; exit 0; }

    existing_tags=()
    while IFS= read -r -d '' tag; do existing_tags+=("$tag"); done < <(split_tags "$current_tags_str")

    multi_args=()
    while IFS= read -r -d '' word; do multi_args+=("$word"); done < <(dmenu_multi_flag_args)

    # Step 2: which of the bookmark's current tags to keep. Without multi-select
    # there's no way to choose a subset, so skip the picker and keep them all.
    kept_tags=()
    if [[ ${#existing_tags[@]} -gt 0 && -n "$DMENU_MULTI_FLAG" ]]; then
        selected_existing=$(printf '%s\n' "${existing_tags[@]}" | "${DMENU_CMD[@]}" "${multi_args[@]}") || { qute_message "Cancelled"; exit 0; }
        while IFS= read -r line; do
            [[ -n "$line" ]] && kept_tags+=("$line")
        done <<< "$selected_existing"
    else
        kept_tags=("${existing_tags[@]}")
    fi

    # Step 3: multi-select additional tags already used elsewhere (buku --stag's tag
    # list), excluding ones already kept. Without multi-select, skip straight past it.
    autocompleted_tags=()
    if [[ -n "$DMENU_MULTI_FLAG" ]]; then
        all_tags=()
        while IFS= read -r line; do
            [[ "$line" =~ ^[[:space:]]*[0-9]+\.[[:space:]]+(.*)[[:space:]]\([0-9]+\)$ ]] && all_tags+=("${BASH_REMATCH[1]}")
        done < <(buku --nostdin --stag 2>/dev/null)

        offerable_tags=()
        for tag in "${all_tags[@]}"; do
            already_kept=false
            for kept in "${kept_tags[@]}"; do
                [[ "$tag" == "$kept" ]] && { already_kept=true; break; }
            done
            [[ "$already_kept" == false ]] && offerable_tags+=("$tag")
        done

        if [[ ${#offerable_tags[@]} -gt 0 ]]; then
            selected_auto=$(printf '%s\n' "${offerable_tags[@]}" | "${DMENU_CMD[@]}" "${multi_args[@]}") || { qute_message "Cancelled"; exit 0; }
            while IFS= read -r line; do
                [[ -n "$line" ]] && autocompleted_tags+=("$line")
            done <<< "$selected_auto"
        fi
    fi

    # Step 4: free-text entry for any brand new tags.
    reminder_tags=("${kept_tags[@]}" "${autocompleted_tags[@]}")
    printf -v reminder_str '%s, ' "${reminder_tags[@]:-}"
    reminder="Selected tags: ${reminder_str%, }"

    msg_args=()
    while IFS= read -r -d '' word; do msg_args+=("$word"); done < <(dmenu_msg_flag_args "$reminder")
    extra_tags_str=$(printf '' | "${DMENU_CMD[@]}" "${msg_args[@]}") || { qute_message "Cancelled"; exit 0; }

    all_tags_final=("${kept_tags[@]}" "${autocompleted_tags[@]}")
    while IFS= read -r -d '' tag; do all_tags_final+=("$tag"); done < <(split_tags "$extra_tags_str")

    tags_str=""
    if [[ ${#all_tags_final[@]} -gt 0 ]]; then
        mapfile -t all_tags_final < <(printf '%s\n' "${all_tags_final[@]}" | sort -u)
        printf -v tags_str '%s, ' "${all_tags_final[@]}"
        tags_str="${tags_str%, }"
    fi

    buku_args=("-u" "$id" "--title" "$new_title" "--tag")
    [[ -n "$tags_str" ]] && buku_args+=("$tags_str")
    field_desc="title, tags"
else
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
    field_desc="$field"
fi

stderr_file=$(mktemp)
buku_exit_code=0
buku_stdout=$(buku --nostdin "${buku_args[@]}" 2>"$stderr_file") || buku_exit_code=$?
buku_stderr=$(cat "$stderr_file")
rm -f "$stderr_file"

if [[ $buku_exit_code -ne 0 ]]; then
    qute_error "Unknown error while updating $id_or_url"
else
    qute_message "Updated $id_or_url ($field_desc)"
fi

printf '%s\n' "$buku_stdout"
printf '%s\n' "$buku_stderr" >&2
