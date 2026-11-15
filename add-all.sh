#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"

usage() {
    echo "Usage: $(basename "$0") [--windows <active|non-private|all>] [--prefix <prefix>] [--tags <tag, ...>]" >&2
    echo "       $(basename "$0")     [--auto-fetch-tags[=<true|false>]] [-q|--quiet] [URL ...]" >&2
    echo "  --windows <mode>                  which qutebrowser windows to collect tabs from (qutebrowser mode only):" >&2
    echo "                                      active       the current window, private or not (default)" >&2
    echo "                                      non-private  every non-private window" >&2
    echo "                                      all          every window, private ones included" >&2
    echo "  --prefix <prefix>                 prepended as-is to every bookmark's title" >&2
    echo "  --tags <tag, ...>                 comma-separated tags added to every bookmark" >&2
    echo "  --auto-fetch-tags[=<true|false>]  override AUTO_FETCH_TAGS for this invocation (bare flag means true)" >&2
    echo "  -q, --quiet                       skip the interactive prefix/tag prompts in qutebrowser mode" >&2
    echo "  URL ...                           pages to bookmark instead of the open tabs (always non-interactive)" >&2
    exit 1
}

windows=active
windows_set=false
prefix=""
prefix_set=false
tags_str=""
tags_set=false
quiet=false
args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --windows)
            [[ $# -lt 2 ]] && usage
            windows="$2"; windows_set=true; shift 2
            ;;
        --windows=*) windows="${1#--windows=}"; windows_set=true; shift ;;
        --prefix)
            [[ $# -lt 2 ]] && usage
            prefix="$2"; prefix_set=true; shift 2
            ;;
        --prefix=*) prefix="${1#--prefix=}"; prefix_set=true; shift ;;
        --tags)
            [[ $# -lt 2 ]] && usage
            tags_str="$2"; tags_set=true; shift 2
            ;;
        --tags=*) tags_str="${1#--tags=}"; tags_set=true; shift ;;
        --auto-fetch-tags) AUTO_FETCH_TAGS=true; shift ;;
        --auto-fetch-tags=*) AUTO_FETCH_TAGS="${1#--auto-fetch-tags=}"; shift ;;
        -q|--quiet) quiet=true; shift ;;
        -h|--help) usage ;;
        --) shift; args+=("$@"); break ;;
        -*) usage ;;
        *) args+=("$1"); shift ;;
    esac
done

case "$windows" in
    active)      session_flags="--only-active-window --with-private" ;;
    non-private) session_flags="" ;;
    all)         session_flags="--with-private" ;;
    *) qute_error "--windows must be one of: active, non-private, all"; exit 1 ;;
esac

is_qb_mode=false
[[ -n "${QUTE_FIFO:-}" ]] && is_qb_mode=true

for url in "${args[@]}"; do
    if [[ ! "$url" =~ ^https?:// ]] && [[ ! "$url" =~ ^ftps?:// ]]; then
        qute_error "URL '$url' must begin with http://, https://, ftp://, or ftps://"; exit 1
    fi
done

from_tabs=false
if [[ ${#args[@]} -eq 0 ]]; then
    [[ "$is_qb_mode" == false ]] && usage
    from_tabs=true
fi

if [[ "$windows_set" == true && "$from_tabs" == false ]]; then
    echo "Warning: --windows has no effect when URLs are given explicitly" >&2
fi
if [[ "$quiet" == true && "$is_qb_mode" == false ]]; then
    echo "Warning: -q/--quiet has no effect when run outside of qutebrowser" >&2
fi

interactive=false
[[ "$from_tabs" == true && "$quiet" == false ]] && interactive=true

titles=()
urls=()
if [[ "$from_tabs" == true ]]; then
    require_yq

    # Have qutebrowser dump its tabs to a throwaway session (names starting with
    # '_' are internal, hence --force), then read the current page of each tab.
    # Sessions are written atomically, so the file existing means it's complete.
    session_name="_qb-buku-$(basename "$(mktemp -u -t XXXXXXXXXXXX)")"
    session_file="$QUTE_DATA_DIR/sessions/$session_name.yml"
    trap 'rm -f "$session_file"' EXIT

    printf 'session-save --force --quiet --no-history %s %s\n' "$session_flags" "$session_name" >> "$QUTE_FIFO"
    for ((i = 0; i < 100; i++)); do
        [[ -f "$session_file" ]] && break
        sleep 0.1
    done
    if [[ ! -f "$session_file" ]]; then
        qute_error "Timed out waiting for qutebrowser to save session '$session_name'"; exit 1
    fi

    # Each tab's current page is its history entry marked active (with --no-history
    # only one entry is saved, and it isn't always marked), keeping only
    # bookmarkable URLs, deduplicated in order.
    while IFS= read -r -d '' title && IFS= read -r -d '' url; do
        titles+=("$title")
        urls+=("$url")
    done < <(yq -j '
        [.windows[]?.tabs[]?
            | (.history // []) as $h
            | (([$h[] | select(.active)] | first) // $h[-1])
            | select(. != null and ((.url // "") | test("^(https?|ftps?)://")))
            | {title: (.title // "" | gsub("\n";" ")), url}]
        | reduce .[] as $t ([]; if any(.[]; .url == $t.url) then . else . + [$t] end)
        | .[] | "\(.title)\u0000\(.url)\u0000"
    ' "$session_file")
    rm -f "$session_file"

    if [[ ${#urls[@]} -eq 0 ]]; then
        qute_error "No bookmarkable tabs found"; exit 0
    fi
else
    urls=("${args[@]}")
fi

if [[ "$interactive" == true ]]; then
    if [[ "$prefix_set" == false ]]; then
        msg_args=()
        while IFS= read -r -d '' word; do msg_args+=("$word"); done < <(dmenu_msg_flag_args "Title prefix for ${#urls[@]} bookmark(s) (optional)")
        prefix=$(printf '' | "${DMENU_CMD[@]}" "${msg_args[@]}") || { qute_message "Cancelled"; exit 0; }
    fi

    if [[ "$tags_set" == false ]]; then
        if [[ "$AUTO_FETCH_TAGS" == true ]]; then
            reminder="Tags for ${#urls[@]} bookmark(s), added to each page's auto-fetched tags (optional)"
        else
            reminder="Tags for ${#urls[@]} bookmark(s) (optional)"
        fi
        msg_args=()
        while IFS= read -r -d '' word; do msg_args+=("$word"); done < <(dmenu_msg_flag_args "$reminder")
        tags_str=$(printf '' | "${DMENU_CMD[@]}" "${msg_args[@]}") || { qute_message "Cancelled"; exit 0; }
    fi
fi

all_tags=()
while IFS= read -r -d '' tag; do all_tags+=("$tag"); done < <(split_tags "$tags_str")
tags_str=""
if [[ ${#all_tags[@]} -gt 0 ]]; then
    mapfile -t all_tags < <(printf '%s\n' "${all_tags[@]}" | sort -u)
    printf -v tags_str '%s, ' "${all_tags[@]}"
    tags_str="${tags_str%, }"
fi

added=0
existing=0
failed=0
for i in "${!urls[@]}"; do
    url="${urls[$i]}"
    title="${titles[$i]:-}"

    buku_args=("--add" "$url")
    [[ "$AUTO_FETCH_TAGS" == true ]] && buku_args+=("+")
    [[ -n "$tags_str" ]] && buku_args+=("$tags_str")

    # Online, buku fetches the page's tags even without '+', so unless they're wanted
    # the add has to be --offline -- which means knowing the title up front. Tabs
    # already have one; explicit URLs need it fetched (also needed for the prefix).
    if [[ "$from_tabs" == false && ( -n "$prefix" || "$AUTO_FETCH_TAGS" != true ) ]]; then
        title=$("$PYTHON" "$here/fetch-preview.py" "$url" | head -n1) || title=""
        [[ -z "$title" ]] && echo "Warning: couldn't fetch a title for $url" >&2
    fi

    if [[ "$from_tabs" == true || -n "$prefix" || "$AUTO_FETCH_TAGS" != true ]]; then
        buku_args+=("--title" "$prefix$title")
    fi
    [[ "$AUTO_FETCH_TAGS" != true ]] && buku_args+=("--offline")

    stderr_file=$(mktemp)
    buku_exit_code=0
    buku_stdout=$(buku --nostdin "${buku_args[@]}" 2>"$stderr_file") || buku_exit_code=$?
    buku_stderr=$(cat "$stderr_file")
    rm -f "$stderr_file"

    if [[ $buku_exit_code -ne 0 ]]; then
        echo "Error: unknown error while adding $url" >&2
        failed=$((failed + 1))
    elif [[ "$(strip_ansi "$buku_stderr")" =~ ^\[ERROR\] ]]; then
        echo "$url already exists"
        existing=$((existing + 1))
    else
        added=$((added + 1))
    fi

    printf '%s\n' "$buku_stdout"
    printf '%s\n' "$buku_stderr" >&2
done

summary="Added $added, $existing already existed, $failed failed"
if [[ $failed -gt 0 ]]; then
    qute_error "$summary"
else
    qute_message "$summary"
fi
