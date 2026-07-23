#!/usr/bin/env bash
set -uo pipefail

case "${1:-}" in
  set)
    path="$2"
    [ -f "$path" ] || { echo "file not found: $path" >&2; exit 1; }

    # Set desktop wallpaper via awww
    awww img "$path" --transition-type grow --transition-pos "0.5,1.0" --transition-fps 60 --transition-step 90 --transition-duration 0.5 || true

    # Update quickshell lockscreen wallpaper (dingaling theme)
    lock_theme="$HOME/Projects/qylock/qylock/themes/dingaling"
    [ -d "$lock_theme" ] && cp "$path" "$lock_theme/bg.jpg" 2>/dev/null || true

    # Update SDDM lockscreen wallpaper (dingaling theme)
    sddm_theme="/usr/share/sddm/themes/dingaling"
    [ -d "$sddm_theme" ] && cp "$path" "$sddm_theme/bg.png" 2>/dev/null || true

    # Save state for Walls.qml to pick up
    state="${XDG_STATE_HOME:-$HOME/.local/state}/dingaling-wallpaper"
    mkdir -p "$(dirname "$state")"
    printf '%s\n' "$path" > "$state"

    # Generate colours via matugen and reload the shell
    "$HOME/.config/scripts/dingaling/wallcolors.sh" "$path" &
    ;;
  *)
    echo "usage: ${0##*/} set <path>" >&2
    exit 1
    ;;
esac
