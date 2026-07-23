#!/usr/bin/env bash
set -uo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dingaling"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dingaling"
COLORS="$CACHE/colors.json"
OVERRIDES_FILE="$STATE/overrides.json"
SDDM_THEME="/usr/share/sddm/themes/dingaling"

mkdir -p "$CACHE" "$STATE"

# Read overrides: first arg, then stdin, then state file
if [ $# -ge 1 ] && [ -n "$1" ]; then
    overrides="$1"
elif [ -f "$OVERRIDES_FILE" ]; then
    overrides=$(cat "$OVERRIDES_FILE")
else
    overrides="{}"
fi

echo "$overrides" > "$OVERRIDES_FILE"
[ -f "$COLORS" ] || exit 0

python3 -c "
import json, sys

with open('$COLORS') as f:
    colors = json.load(f)

overrides = json.loads('''$overrides''')

for key, val in overrides.items():
    if val and isinstance(val, str) and val.startswith('#'):
        colors[key] = val

with open('$COLORS', 'w') as f:
    json.dump(colors, f, indent=2)
    f.write('\n')
"

if [ -d "$SDDM_THEME" ]; then
    cp "$COLORS" "$SDDM_THEME/colors.json" 2>/dev/null || true
fi

hyprctl reload >/dev/null 2>&1 || true
busctl --user call com.mitchellh.ghostty \
    /com/mitchellh/ghostty org.gtk.Actions Activate \
    "sava{sv}" reload-config 0 0 >/dev/null 2>&1 || true
