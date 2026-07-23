#!/bin/bash

SOCK="${SWAYSOCK}"
[ -z "$SOCK" ] || [ ! -S "$SOCK" ] && SOCK=$(ls -t /run/user/1000/scroll-ipc.*.sock 2>/dev/null | head -1)
[ -z "$SOCK" ] && exit 0

JSON_FILE="$HOME/.config/scroll/persistent-spaces.json"
SCROLLMSG=(scrollmsg -s "$SOCK")

[ ! -f "$JSON_FILE" ] && exit 0

launch_leaf() {
  local app_id="$1"
  local cmd="${2:-$app_id}"
  local exists
  exists=$("${SCROLLMSG[@]}" -t get_tree | jq -e --arg app "$app_id" '[.. | select(type == "object" and .app_id? == $app)] | length > 0' &>/dev/null && echo true || echo false)
  if [ "$exists" = "true" ]; then
    "${SCROLLMSG[@]}" "[app_id=\"$app_id\"] move workspace current" 2>/dev/null
    return
  fi
  "${SCROLLMSG[@]}" "exec" "$cmd"
  local tries=0
  while [ $tries -lt 30 ]; do
    local after
    after=$("${SCROLLMSG[@]}" -t get_tree | jq --arg app "$app_id" '[.. | select(type == "object" and .app_id? == $app)] | length')
    [ "$after" -gt 0 ] && break
    sleep 0.3
    tries=$((tries + 1))
  done
}

_restore_tree() {
  local node="$1"
  local type
  type=$(echo "$node" | jq -r 'type')

  if [ "$type" = "string" ]; then
    launch_leaf "$(echo "$node" | jq -r '.')"
    return
  fi

  if [ "$type" = "object" ] && echo "$node" | jq -e '.app_id and (.children | not)' &>/dev/null; then
    launch_leaf "$(echo "$node" | jq -r '.app_id')" "$(echo "$node" | jq -r '.command // .app_id')"
    return
  fi

  local layout
  layout=$(echo "$node" | jq -r '.layout // ""')
  local count
  count=$(echo "$node" | jq '.children | length')
  [ "$count" = "0" ] && return

  local i=0
  while [ $i -lt $count ]; do
    local child
    child=$(echo "$node" | jq -c ".children[$i]")

    if [ $i -gt 0 ]; then
      "${SCROLLMSG[@]}" "set_mode" "${layout:0:1}"
    fi

    _restore_tree "$child"

    i=$((i + 1))
  done
}

ws=1
for label in $(jq -r 'keys[]' "$JSON_FILE"); do
  "${SCROLLMSG[@]}" "workspace" "$ws"
  sleep 0.2
  node=$(jq -c ".[\"$label\"].layout" "$JSON_FILE" 2>/dev/null)
  if [ -n "$node" ] && [ "$node" != "null" ]; then
    root_layout=$(echo "$node" | jq -r '.layout // ""')
    if [ -n "$root_layout" ]; then
      "${SCROLLMSG[@]}" "set_mode" "${root_layout:0:1}"
    fi
    _restore_tree "$node"
  fi
  "${SCROLLMSG[@]}" "space save" "\"$label\""
  local focused
  focused=$(jq -r ".[\"$label\"].focused_app // \"\"" "$JSON_FILE" 2>/dev/null)
  if [ -n "$focused" ]; then
    "${SCROLLMSG[@]}" "[app_id=\"$focused\"] focus" 2>/dev/null
  fi
  ws=$((ws + 1))
done
