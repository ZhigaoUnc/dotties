#!/bin/bash
# Make sure scrollmsg can find the IPC socket
export SWAYSOCK=$(ls /run/user/1000/scroll-ipc.* 2>/dev/null | head -1)
export SCROLLSOCK="$SWAYSOCK"
FIREBASE_URL="${FIREBASE_URL:?Set FIREBASE_URL in your environment}"
MY_KEY="${MY_KEY:?Set MY_KEY in your environment}"
INTERVAL=60

while true; do
  FOCUSED=$(scrollmsg -t get_tree | jq -r '.. | select(.type? and .focused == true)')
  if [ -z "$FOCUSED" ] || [ "$FOCUSED" = "null" ]; then
    APP_CLASS="idle"
  else
    APP_CLASS=$(echo "$FOCUSED" | jq -r '.app_id // .window_properties.class // "unknown"')
  fi

  CURRENT_UPTIME=$(awk '{print int($1)}' /proc/uptime)
  THIS_WEEK=$(date +%G-%V)
  TODAY=$(date +%Y-%m-%d)

  # Fetch current remote state
  REMOTE=$(curl -s "$FIREBASE_URL/status/$MY_KEY.json")
  REMOTE_BASE=$(echo "$REMOTE" | jq -r '.base // 0')
  REMOTE_LAST_UPTIME=$(echo "$REMOTE" | jq -r '.last_uptime // 0')
  REMOTE_WEEK=$(echo "$REMOTE" | jq -r '.week // ""')
  REMOTE_DAILY_BASE=$(echo "$REMOTE" | jq -r '.daily_base // 0')
  REMOTE_DAILY_DATE=$(echo "$REMOTE" | jq -r '.daily_date // ""')
  REMOTE_DAYS=$(echo "$REMOTE" | jq -r '.days // {}')

  # === WEEKLY LOGIC (unchanged) ===
  if [ "$THIS_WEEK" != "$REMOTE_WEEK" ]; then
    BASE=0
  elif [ "$CURRENT_UPTIME" -lt "$REMOTE_LAST_UPTIME" ]; then
    BASE=$((REMOTE_BASE + REMOTE_LAST_UPTIME))
  else
    BASE=$REMOTE_BASE
  fi
  WEEKLY_TOTAL=$((BASE + CURRENT_UPTIME))

  # === DAILY LOGIC (new) ===
  # If day changed, save yesterday's total to days object
  if [ "$TODAY" != "$REMOTE_DAILY_DATE" ] && [ -n "$REMOTE_DAILY_DATE" ]; then
    YESTERDAY_TOTAL=$((REMOTE_DAILY_BASE + REMOTE_LAST_UPTIME))
    REMOTE_DAYS=$(echo "$REMOTE_DAYS" | jq --arg date "$REMOTE_DAILY_DATE" --argjson total "$YESTERDAY_TOTAL" '.[$date] = $total')
  fi

  # Reset daily base if day changed, handle reboots within same day
  if [ "$TODAY" != "$REMOTE_DAILY_DATE" ]; then
    DAILY_BASE=0
  elif [ "$CURRENT_UPTIME" -lt "$REMOTE_LAST_UPTIME" ]; then
    DAILY_BASE=$((REMOTE_DAILY_BASE + REMOTE_LAST_UPTIME))
  else
    DAILY_BASE=$REMOTE_DAILY_BASE
  fi

  # Today's total so far
  DAILY_TOTAL=$((DAILY_BASE + CURRENT_UPTIME))

  # === BUILD PAYLOAD ===
  PAYLOAD=$(jq -n \
    --arg app "$APP_CLASS" \
    --argjson screentime "$WEEKLY_TOTAL" \
    --argjson base "$BASE" \
    --argjson last_uptime "$CURRENT_UPTIME" \
    --arg week "$THIS_WEEK" \
    --arg updated "$(date -u +%FT%TZ)" \
    --argjson daily_base "$DAILY_BASE" \
    --arg daily_date "$TODAY" \
    --argjson daily_total "$DAILY_TOTAL" \
    --argjson days "$REMOTE_DAYS" \
    '{
      app: $app,
      screentime: $screentime,
      base: $base,
      last_uptime: $last_uptime,
      week: $week,
      updated: $updated,
      daily_base: $daily_base,
      daily_date: $daily_date,
      daily_total: $daily_total,
      days: $days
    }')

  curl -s -X PUT "$FIREBASE_URL/status/$MY_KEY.json" \
    -d "$PAYLOAD" >/dev/null

  sleep "$INTERVAL"
done
