#!/bin/bash

SOCK="${SWAYSOCK}"
[ -z "$SOCK" ] || [ ! -S "$SOCK" ] && SOCK=$(ls -t /run/user/1000/scroll-ipc.*.sock 2>/dev/null | head -1)
[ -z "$SOCK" ] && { echo "scroll not running"; exit 1; }

JSON_FILE="$HOME/.config/scroll/persistent-spaces.json"
SCROLLMSG=(scrollmsg -s "$SOCK")

capture_tree() {
  local fws
  fws=$("${SCROLLMSG[@]}" -t get_workspaces | jq -r '.[] | select(.focused) | .name')
  "${SCROLLMSG[@]}" -t get_tree | jq -c --arg name "$fws" '
    def capture:
      if .type == "workspace" and .name == $name then
        {layout: (.layout | tostring), children: [.nodes[]? | capture]}
      elif .nodes and (.nodes | length) > 0 then
        {layout: (.layout | tostring), children: [.nodes[]? | capture]}
      elif .app_id then
        .app_id
      else
        empty
      end;
    [.. | select(.type? == "workspace" and .name == $name)] | first | capture
  '
}

save() {
  local label
  label=$(rofi -p "Save space name" -dmenu)
  [ -z "$label" ] && exit 1

  "${SCROLLMSG[@]}" "space save" "\"$label\""

  local tree ws_num
  tree=$(capture_tree)

  # Derive launch command: for reverse-DNS app_ids (e.g. org.pulseaudio.pavucontrol),
  # strip all but the last component. Otherwise use app_id as-is.
  tree=$(echo "$tree" | jq -c '
    def cmd:
      if type == "string" then
        if (split(".") | length > 1) then split(".")[-1] else . end
      else .
      end;
    def enrich:
      if type == "string" then
        {app_id: ., command: cmd}
      elif .children then
        {layout: .layout, children: [.children[] | enrich]}
      else .
      end;
    enrich
  ')

  local focused_app
  focused_app=$(echo "$tree" | jq -r '[.. | select(type == "object" and .app_id) | .app_id] | unique | .[]' | rofi -p "Focus app after restore" -dmenu)
  [ -z "$focused_app" ] && focused_app=""

  [ ! -f "$JSON_FILE" ] && echo '{}' > "$JSON_FILE"
  jq --arg key "$label" --argjson tree "$tree" --arg focused "$focused_app" \
    '.[$key] = {"space": $key, "layout": $tree, "focused_app": $focused}' "$JSON_FILE" \
    > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
}

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

restore_layout() {
  local label="$1"
  local node
  node=$(jq -c ".[\"$label\"].layout" "$JSON_FILE" 2>/dev/null)
  [ -z "$node" ] || [ "$node" = "null" ] && return

  local root_layout
  root_layout=$(echo "$node" | jq -r '.layout // ""')
  if [ -n "$root_layout" ]; then
    "${SCROLLMSG[@]}" "set_mode" "${root_layout:0:1}"
  fi

  _restore_tree "$node"

  local focused
  focused=$(jq -r ".[\"$label\"].focused_app // \"\"" "$JSON_FILE" 2>/dev/null)
  if [ -n "$focused" ]; then
    "${SCROLLMSG[@]}" "[app_id=\"$focused\"] focus" 2>/dev/null
  fi
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

load() {
  local label
  label=$(jq -r 'keys[]' "$JSON_FILE" | rofi -p "Load space" -dmenu)
  [ -z "$label" ] && exit 1

  "${SCROLLMSG[@]}" "space load" "\"$label\""
  restore_layout "$label"
}

restore() {
  local label
  label=$(jq -r 'keys[]' "$JSON_FILE" | rofi -p "Restore space (close others)" -dmenu)
  [ -z "$label" ] && exit 1
  "${SCROLLMSG[@]}" "space restore" "\"$label\""
  restore_layout "$label"
}

restore_hide() {
  local label
  label=$(jq -r 'keys[]' "$JSON_FILE" | rofi -p "Restore space (hide others)" -dmenu)
  [ -z "$label" ] && exit 1
  "${SCROLLMSG[@]}" "space restore_hide" "\"$label\""
  restore_layout "$label"
}

delete() {
  local label
  label=$(jq -r 'keys[]' "$JSON_FILE" | rofi -p "Delete space" -dmenu)
  [ -z "$label" ] && exit 1
  "${SCROLLMSG[@]}" "space delete" "\"$label\"" 2>/dev/null
  [ -f "$JSON_FILE" ] && jq "del(.[\"$label\"])" "$JSON_FILE" \
    > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
}

case "$1" in
  save) save ;;
  load) load ;;
  restore) restore ;;
  restore_hide) restore_hide ;;
  delete) delete ;;
  *)
    echo "Usage: $0 {save|load|restore|restore_hide|delete}"
    exit 1
    ;;
esac
