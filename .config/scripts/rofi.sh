#!/bin/bash
# Single symbol-based launcher with async file loading
# Bind: bindsym $mod+space exec bash ~/.config/rofi/launcher.sh

VAULT_DIR="$HOME/ZaWaruto"
SCREENSHOT_DIR="$HOME/screenshots"

# Get initial input
result=$(rofi -dmenu -p "λ" -lines 0 -width 500)
[ -z "$result" ] && exit

symbol="${result:0:1}"
input="${result:1}"

# Check for space after symbol (triggers search mode)
if [[ "$input" =~ ^[[:space:]] ]]; then
  filter="${input#*[[:space:]]*}"

  case "$symbol" in
  ">")
    # File search - async with rofi
    # Generate file list in background, feed to rofi immediately
    tmpfifo=$(mktemp -u)
    mkfifo "$tmpfifo"

    find ~/ -type f 2>/dev/null >"$tmpfifo" &
    file=$(rofi -dmenu -p "> " -filter "$filter" <"$tmpfifo")

    rm -f "$tmpfifo"
    [ -n "$file" ] && xdg-open "$file"
    ;;

  "#")
    # Obsidian vault search - async
    tmpfifo=$(mktemp -u)
    mkfifo "$tmpfifo"

    find "$VAULT_DIR" -name "*.md" 2>/dev/null >"$tmpfifo" &
    note=$(rofi -dmenu -p "# " -filter "$filter" <"$tmpfifo")

    rm -f "$tmpfifo"
    [ -n "$note" ] && xdg-open "$note"
    ;;

  "~")
    # Directory jump - async
    if command -v zoxide &>/dev/null; then
      tmpfifo=$(mktemp -u)
      mkfifo "$tmpfifo"

      zoxide query -l >"$tmpfifo" &
      dir=$(rofi -dmenu -p "~ " -filter "$filter" <"$tmpfifo")

      rm -f "$tmpfifo"
      [ -n "$dir" ] && cd "$dir" && notify-send "~" "Jumped to $dir"
    else
      notify-send "zoxide not installed"
    fi
    ;;

  ".")
    # Recent files - async
    tmpfifo=$(mktemp -u)
    mkfifo "$tmpfifo"

    find ~/ -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -50 | cut -d' ' -f2- >"$tmpfifo" &
    recent=$(rofi -dmenu -p ". " -filter "$filter" <"$tmpfifo")

    rm -f "$tmpfifo"
    [ -n "$recent" ] && xdg-open "$recent"
    ;;

  *)
    notify-send "λ" "? > # ~ . @ / $ ! | = ; &"
    ;;
  esac
  exit
fi

# No space after symbol - handle direct commands
case "$symbol" in
"?")
  # Dictionary
  word=$(echo "$input" | xargs)
  if [ -z "$word" ]; then
    notify-send "?" "? <word>"
  else
    xdg-open "https://www.wiktionary.org/wiki/$word"
  fi
  ;;

"@")
  # Calculator
  result=$(echo "$input" | bc 2>/dev/null)
  notify-send "@" "$result" 2>/dev/null || echo "$result"
  ;;

"/")
  # Web search
  query_clean=$(echo "$input" | xargs | sed 's/ /+/g')
  xdg-open "https://duckduckgo.com/?q=$query_clean"
  ;;

"$")
  # Git commands
  if [ -z "$input" ]; then
    git status
  else
    cmd="${input%% *}"
    case "$cmd" in
    status) git status ;;
    log) git log --oneline -10 ;;
    add) git add . && notify-send "$" "Added all files" ;;
    commit) git commit -m "${input#* }" && notify-send "$" "Committed" ;;
    push) git push && notify-send "$" "Pushed" ;;
    pull) git pull && notify-send "$" "Pulled" ;;
    *) notify-send "$" "status/log/add/commit/push/pull" ;;
    esac
  fi
  ;;

"!")
  # Kill process
  process=$(ps aux | awk 'NR>1 {print $11}' | sort -u | fzf)
  [ -n "$process" ] && pkill -f "$process" && notify-send "!" "Killed: $process"
  ;;

"|")
  # Pipe clipboard
  clipboard=$(wl-paste 2>/dev/null)
  case "$input" in
  jq) echo "$clipboard" | jq '.' 2>/dev/null | wl-copy && notify-send "|" "jq" ;;
  base64) echo "$clipboard" | base64 -d 2>/dev/null | wl-copy && notify-send "|" "decoded" ;;
  url) echo "$clipboard" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read()))" 2>/dev/null | wl-copy && notify-send "|" "url-decoded" ;;
  rev) echo "$clipboard" | rev | wl-copy && notify-send "|" "reversed" ;;
  *) notify-send "|" "jq/base64/url/rev" ;;
  esac
  ;;

"=")
  # Unit converter
  notify-send "=" "= (not implemented)"
  ;;

";")
  # Quick note
  mkdir -p "$VAULT_DIR"
  echo "- $(date '+%Y-%m-%d %H:%M') $input" >>"$VAULT_DIR/quick-notes.md"
  notify-send ";" "Added to quick notes"
  ;;

"&")
  # Screenshot
  mkdir -p "$SCREENSHOT_DIR"
  case "$input" in
  full) grim "$SCREENSHOT_DIR/$(date +%s).png" && notify-send "&" "Screenshot saved" ;;
  select) grim -g "$(slurp)" "$SCREENSHOT_DIR/$(date +%s).png" && notify-send "&" "Screenshot saved" ;;
  *) notify-send "&" "full/select" ;;
  esac
  ;;

*)
  notify-send "λ" "? (dict) > (files) # (vault) ~ (dir) . (recent) @ (calc) / (web) $ (git) ! (kill) | (pipe) = (convert) ; (note) & (screenshot)"
  ;;
esac
