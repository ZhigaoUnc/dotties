#!/usr/bin/env bash
# Used by lutris-banner-fetcher.sh for fzf image previews
file="$1"
[[ -f "$file" ]] || exit 0
kitten icat --clear --transfer-mode=stream --stdin=no "$file" 2>/dev/null
