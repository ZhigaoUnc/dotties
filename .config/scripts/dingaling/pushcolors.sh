#!/usr/bin/env bash
set -uo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dingaling"
SDDM_QML="/usr/share/sddm/themes/dingaling/Main.qml"

"$HOME/.config/scripts/dingaling/override.sh" apply

rewrite_sddm_qml() {
    local json="$1"
    [ -f "$json" ] || return 0
    local qml="$SDDM_QML"
    python3 -c "
import json, re
j = json.load(open('${json}'))
m = {
    'cInk':    j.get('cream', '#ffffff'),
    'cDim':    j.get('dim', '#888888'),
    'cFaint':  j.get('surface_container_high', '#111111'),
    'cRule':   j.get('outline_variant', '#222222'),
    'cHint':   j.get('subtle', '#555555'),
    'cAccent': j.get('primary', '#ffffff'),
}
c = open('${qml}').read()
for prop, val in m.items():
    c = re.sub(r'property color ' + prop + r':\s*\"#[^\"]*\"',
               r'property color ' + prop + r': \"' + val + r'\"', c)
open('${qml}', 'w').write(c)
" 2>/dev/null || true
}

cp "$CACHE/colors.json" /usr/share/sddm/themes/dingaling/colors.json 2>/dev/null || true
rewrite_sddm_qml "$CACHE/colors.json"

vicinae theme set matugen 2>/dev/null || true

hyprctl reload >/dev/null 2>&1 || true

busctl --user call com.mitchellh.ghostty \
    /com/mitchellh/ghostty org.gtk.Actions Activate \
    "sava{sv}" reload-config 0 0 >/dev/null 2>&1 || true
