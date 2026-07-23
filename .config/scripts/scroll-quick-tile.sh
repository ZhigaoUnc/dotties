#!/bin/bash

input=$(rofi -dmenu -p "Quick tile (app : app : ...):")
[ -z "$input" ] && exit 1

known_apps=$( {
  ls /usr/share/applications/*.desktop 2>/dev/null | xargs -I{} basename {} .desktop
  scrollmsg -t get_tree 2>/dev/null | jq -r '[.. | select(.app_id? and .app_id != null) | .app_id] | .[]'
} | sort -u | tr '[:upper:]' '[:lower:]')

IFS=':' read -ra tokens <<< "$input"
for token in "${tokens[@]}"; do
  token=$(echo "$token" | xargs)
  [ -z "$token" ] && continue

  match=$(echo "$known_apps" | fzf -f "$token" | head -1)
  [ -z "$match" ] && match="$token"

  if scrollmsg -t get_tree 2>/dev/null | jq -e --arg id "$match" '[.. | select(.app_id? and .app_id != null) | .app_id | ascii_downcase] | contains([$id | ascii_downcase])' > /dev/null; then
    scrollmsg "[app_id=\"$match\"] focus; move workspace current"
  else
    gtk-launch "$match" 2>/dev/null || "$match" &

    for i in $(seq 1 20); do
      if scrollmsg -t get_tree 2>/dev/null | jq -e --arg id "$match" '[.. | select(.app_id? and .app_id != null) | .app_id | ascii_downcase] | contains([$id | ascii_downcase])' > /dev/null; then
        break
      fi
      sleep 0.3
    done
  fi
done
