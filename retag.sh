#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(realpath "$0")")"
source "$here/lib.sh"

usage() {
    echo "Usage: $(basename "$0") [-n|--dry-run] [id|URL ...]" >&2
    echo "  -n, --dry-run  show the tags add_additional_tags would add, without changing anything" >&2
    echo "  id|URL ...     bookmark indices or exact URLs to retag (default: every bookmark)" >&2
    exit 1
}

dry_run=false
args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run) dry_run=true; shift ;;
        -h|--help) usage ;;
        --) shift; args+=("$@"); break ;;
        -*) usage ;;
        *) args+=("$1"); shift ;;
    esac
done

if ! declare -F add_additional_tags &>/dev/null; then
    qute_error "add_additional_tags is not defined in $qb_buku_config"; exit 1
fi

require_jq
json=$(buku --nostdin --print -j 2>/dev/null) || json=""
if [[ -z "$json" || "$json" == "[]" ]]; then
    qute_error "No bookmarks found"; exit 0
fi

# Any id/URL argument that doesn't match a bookmark is only worth a warning.
while IFS= read -r -d '' arg; do
    echo "Warning: no bookmark found for '$arg'" >&2
done < <(jq -j '
    . as $bookmarks
    | $ARGS.positional[]
    | select(. as $a | $bookmarks | any(.[]; (.index | tostring) == $a or .uri == $a) | not)
    | "\(.)\u0000"
' --args "${args[@]}" <<< "$json")

ids=()
urls=()
titles=()
tags=()
while IFS= read -r -d '' id && IFS= read -r -d '' url && IFS= read -r -d '' title && IFS= read -r -d '' tags_str; do
    ids+=("$id")
    urls+=("$url")
    titles+=("$title")
    tags+=("$tags_str")
done < <(jq -j '
    $ARGS.positional as $wanted
    | .[]
    | select(($wanted | length) == 0 or ((.index | tostring) as $i | .uri as $u | $wanted | any(. == $i or . == $u)))
    | "\(.index)\u0000\(.uri)\u0000\(.title // "")\u0000\(.tags // "")\u0000"
' --args "${args[@]}" <<< "$json")

if [[ ${#ids[@]} -eq 0 ]]; then
    qute_error "No matching bookmarks found"; exit 1
fi

retagged=0
failed=0
for i in "${!ids[@]}"; do
    new_str=$(_run_additional_tags_hook "${urls[$i]}" "${titles[$i]}" "${tags[$i]}")
    [[ -z "$new_str" ]] && continue

    if [[ "$dry_run" == false ]] && ! buku --nostdin -u "${ids[$i]}" --tag + "$new_str" >/dev/null 2>&1; then
        echo "Error: couldn't add tags '$new_str' to ${ids[$i]} ${urls[$i]}" >&2
        failed=$((failed + 1))
        continue
    fi
    echo "${ids[$i]} ${urls[$i]}: additional tags: $new_str"
    retagged=$((retagged + 1))
done

if [[ "$dry_run" == true ]]; then
    qute_message "Would retag $retagged of ${#ids[@]} bookmark(s)"
elif [[ $failed -gt 0 ]]; then
    qute_error "Retagged $retagged of ${#ids[@]} bookmark(s), $failed failed"
else
    qute_message "Retagged $retagged of ${#ids[@]} bookmark(s)"
fi
