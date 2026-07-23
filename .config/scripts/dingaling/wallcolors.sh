#!/usr/bin/env bash
set -uo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dingaling"
mkdir -p "$CACHE"

dist_colors() {
    local src="$CACHE/colors.json"
    local dir="/usr/share/sddm/themes/dingaling"
    local qml="$dir/Main.qml"
    [ -f "$src" ] || return 0
    if [ ! -w "$dir" ]; then
        chown "$(id -u):$(id -g)" "$dir" 2>/dev/null || true
    fi
    cp "$src" "$dir/colors.json" 2>/dev/null || true
    python3 -c "
import json, re
j = json.load(open('${src}'))
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

reload() {
    hyprctl reload >/dev/null 2>&1 || true
    busctl --user call com.mitchellh.ghostty \
        /com/mitchellh/ghostty org.gtk.Actions Activate \
        "sava{sv}" reload-config 0 0 >/dev/null 2>&1 || true
}

generate() {
    local hex="$1" mode="$2" scheme="${3:-scheme-tonal-spot}"
    matugen color hex "$hex" -m "$mode" -t "$scheme" -j hex --quiet 2>/dev/null
}

generate_from_image() {
    local image="$1" scheme="${2:-scheme-tonal-spot}"
    [ -f "$image" ] || return 1
    matugen image "$image" -m dark -t "$scheme" -j hex --quiet --prefer darkness 2>/dev/null
}

STATIC_SEED="#111111"

case "${1:-}" in
    --static)
        generate "$STATIC_SEED" "dark" "scheme-monochrome" >/dev/null 2>&1 || true
        cp "$(dirname "$0")/static.json" "$CACHE/colors.json"
        VICINAE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vicinae/themes"
        mkdir -p "$VICINAE_DIR"
        cat > "$VICINAE_DIR/matugen.toml" << 'EOF'
[meta]
name = "Matugen"
description = "AMOLED Monochrome - static variant"
variant = "dark"

[colors.core]
accent = "#ffffff"
accent_foreground = "#ffffff"
background = "#000000"
foreground = "#d4d4d4"
secondary_background = "#0a0a0a"
border = "#333333"

[colors.main_window]
border = "#333333"
[colors.settings_window]
border = "#444444"

[colors.accents]
blue = "#ffffff"
green = "#aaaaaa"
magenta = "#cccccc"
orange = { name = "#888888", lighter = 40 }
red = "#888888"
yellow = { name = "#aaaaaa", lighter = 80 }
cyan = { name = "#ffffff", lighter = 50 }
purple = "#cccccc"

[colors.text]
default = "#d4d4d4"
muted = "#aaaaaa"
danger = "#888888"
success = "#aaaaaa"
placeholder = { name = "#aaaaaa", opacity = 0.6 }

[colors.text.selection]
background = "#ffffff"
foreground = "#000000"
[colors.text.links]
default = "#ffffff"
visited = { name = "#cccccc", darker = 20 }

[colors.input]
border = "#444444"
border_focus = "#ffffff"
border_error = "#888888"

[colors.button.primary]
background = "#151515"
foreground = "#d4d4d4"
[colors.button.primary.hover]
background = "#222222"
[colors.button.primary.focus]
outline = "#ffffff"

[colors.list.item.hover]
background = { name = "#333333", opacity = 0.25 }
foreground = "#d4d4d4"
[colors.list.item.selection]
background = { name = "#444444", opacity = 0.50 }
foreground = "#ffffff"
secondary_background = "#333333"
secondary_foreground = "#ffffff"

[colors.grid.item]
background = "#0a0a0a"
[colors.grid.item.hover]
outline = { name = "#cccccc", opacity = 0.8 }
[colors.grid.item.selection]
outline = { name = "#ffffff" }

[colors.scrollbars]
background = { name = "#ffffff", opacity = 0.2 }

[colors.loading]
bar = "#ffffff"
spinner = "#ffffff"
EOF
        vicinae theme set matugen 2>/dev/null || true
        "$HOME/.config/scripts/dingaling/override.sh" apply
        dist_colors
        reload
        ;;
    --hue)
        hue="$2"
        mode="${3:-dark}"
        sat="${4:-0.5}"
        scheme="${5:-scheme-tonal-spot}"
        hex=$(python3 -c "
import colorsys, sys
h = float(sys.argv[1]) / 360.0
s = float(sys.argv[3])
l = 0.12 if sys.argv[2] == 'dark' else 0.85
r, g, b = colorsys.hls_to_rgb(h, l, s)
print('#%02x%02x%02x' % (round(r*255), round(g*255), round(b*255)))
" "$hue" "$mode" "$sat")
        generate "$hex" "$mode" "$scheme" >/dev/null 2>&1 || true
        "$HOME/.config/scripts/dingaling/override.sh" apply
        dist_colors
        reload
        ;;
    *)
        image="${1:-}"
        scheme="${2:-scheme-tonal-spot}"
        if [ -z "$image" ]; then
            state="${XDG_STATE_HOME:-$HOME/.local/state}/dingaling-wallpaper"
            image=$(cat "$state" 2>/dev/null)
        fi
        [ -f "$image" ] || exit 0
        generate_from_image "$image" "$scheme" >/dev/null 2>&1 || true
        "$HOME/.config/scripts/dingaling/override.sh" apply
        dist_colors
        reload
        ;;
esac
