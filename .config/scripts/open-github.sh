#!/usr/bin/env bash
url=$(git remote get-url origin 2>/dev/null) || {
  notify-send "mode-machine" "Not a git repo"
  exit 1
}

# Strip .git suffix
url="${url%.git}"

# Convert SSH to HTTPS
case "$url" in
git@*)
  url="${url#git@}"
  url="${url/://}"
  url="https://$url"
  ;;
esac

xdg-open "$url"
