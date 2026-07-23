#!/bin/bash
# rofi-symbol-launcher — single launcher for Linux/Sway
# Bind: bindsym $mod+space exec bash ~/.config/scripts/rofi-symbol-launcher.sh
set -o nounset

TD=$(mktemp -d "/tmp/rofi-XXXXXX")
trap 'rm -rf "$TD"' EXIT

notify() { notify-send "λ" "$*"; }

symbol_entries() {
    cat <<'SYM'
> web
~ dirs
? dict
/ files
! kill
| pipe
SYM
}

is_menu_entry() {
    local input="$1" entry
    while IFS= read -r entry; do
        [ "$input" = "$entry" ] && return 0
    done < <(symbol_entries)
    return 1
}

list_mode() {
    local prompt="$1" filter="$2" generator="$3"
    local outfile="$TD/out" fifo="$TD/fifo"

    timeout 15 bash -c "$generator" >"$outfile" 2>/dev/null &
    wait "$!" 2>/dev/null || true

    [ ! -s "$outfile" ] && return 1

    rm -f "$fifo"
    mkfifo "$fifo"
    (cat "$outfile" >"$fifo") &
    local sel
    sel=$(rofi -dmenu -p "$prompt" -filter "$filter" <"$fifo")
    [ -n "$sel" ] && { echo "$sel"; return 0; }
    return 1
}

prompt_input() {
    rofi -dmenu -p "$1"
}

# ─── Mode functions ────────────────────────────────────

mode_files() {
    local filter="$1" file
    file=$(list_mode "/" "$filter" 'find "$HOME" /mnt/shared -maxdepth 5 \( -type f -o -type d \) 2>/dev/null')
    [ -n "$file" ] && notify "$(basename "$file")" && xdg-open "$file"
}

mode_dirs() {
    local filter="$1" dir
    if command -v zoxide &>/dev/null; then
        dir=$(list_mode "~" "$filter" 'zoxide query -l 2>/dev/null')
    else
        dir=$(list_mode "~" "$filter" 'find "$HOME" -maxdepth 3 -type d 2>/dev/null')
    fi
    [ -n "$dir" ] && notify "~ $(basename "$dir")" && xdg-open "$dir"
    [ -n "$dir" ] && command -v zoxide &>/dev/null && zoxide add "$dir" 2>/dev/null || true
}

mode_dict() {
    bash ~/.config/scripts/wikt-lookup.sh
}

mode_web() {
    local query="$1" q
    [ -z "$query" ] && query=$(prompt_input ">")
    q=$(echo "$query" | sed 's/ /+/g')
    [ -n "$q" ] && xdg-open "https://duckduckgo.com/?q=${q}" && notify "> ${query}"
}

mode_kill() {
    local filter="$1" proc
    proc=$(list_mode "!" "$filter" 'ps -eo comm | sort -u | grep -v "^COMMAND$" 2>/dev/null')
    [ -n "$proc" ] && pkill -f "$proc" && notify "! Killed: ${proc}"
}

mode_pipe() {
    local filter="$1" clip
    clip=$(wl-paste 2>/dev/null)
    [ -z "$clip" ] && notify "| Empty clipboard" && return 1
    case "$filter" in
        jq)     echo "$clip" | jq '.' 2>/dev/null | wl-copy && notify "| jq" ;;
        base64) echo "$clip" | base64 -d 2>/dev/null | wl-copy && notify "| base64" ;;
        url)    echo "$clip" | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read()))" 2>/dev/null | wl-copy && notify "| url" ;;
        rev)    echo "$clip" | rev | wl-copy && notify "| rev" ;;
        *)      notify "| jq|base64|url|rev" ;;
    esac
}

# ─── Main ──────────────────────────────────────────────

main() {
    local input sym rest
    # Pass 1: symbols only with auto-select
    input=$(rofi -dmenu -p "λ" -auto-select < <(symbol_entries))
    [ -z "$input" ] && exit 0

    if is_menu_entry "$input"; then
        sym="${input:0:1}"
        rest=""
    elif [[ "$input" =~ ^([>~?/!|]) ]]; then
        sym="${BASH_REMATCH[1]}"
        rest="${input:1}"
        rest="${rest#"${rest%%[![:space:]]*}"}"
    else
        exit 0
    fi

    case "$sym" in
        ">") mode_web    "$rest" ;;
        "~") mode_dirs   "$rest" ;;
        "?") mode_dict   "$rest" ;;
        "/") mode_files  "$rest" ;;
        "!") mode_kill   "$rest" ;;
        "|") mode_pipe   "$rest" ;;
        *)   notify "> ~ ? / ! |" ;;
    esac
}

main "$@"
