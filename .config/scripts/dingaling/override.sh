#!/usr/bin/env bash
set -uo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dingaling"
OVERRIDES="$CACHE/overrides.json"
COLORS="$CACHE/colors.json"

apply() {
    [ -f "$OVERRIDES" ] || return 0
    [ -f "$COLORS" ] || return 0
    python3 -c "
import json
with open('$OVERRIDES') as f: o = json.load(f)
with open('$COLORS') as f: c = json.load(f)
c.update(o)
with open('$COLORS', 'w') as f: json.dump(c, f, indent=2)
" 2>/dev/null
}

set_key() {
    local key="$1" hex="$2"
    mkdir -p "$CACHE"
    if [ -f "$OVERRIDES" ]; then
        python3 -c "
import json
with open('$OVERRIDES') as f: d = json.load(f)
d['$key'] = '$hex'
with open('$OVERRIDES', 'w') as f: json.dump(d, f, indent=2)
" 2>/dev/null
    else
        echo "{\"$key\": \"$hex\"}" > "$OVERRIDES"
    fi
    # Apply immediately so Dyn.qml picks it up
    apply
}

remove_key() {
    local key="$1"
    [ -f "$OVERRIDES" ] || return 0
    python3 -c "
import json
with open('$OVERRIDES') as f: d = json.load(f)
d.pop('$key', None)
with open('$OVERRIDES', 'w') as f: json.dump(d, f, indent=2)
" 2>/dev/null
    apply
}

case "${1:-}" in
    apply) apply ;;
    set)   shift; set_key "$1" "$2" ;;
    remove) shift; remove_key "$1" ;;
    *)
        echo "usage: ${0##*/} {apply|set <key> <hex>|remove <key>}" >&2
        exit 1
        ;;
esac
