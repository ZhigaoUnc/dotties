#!/usr/bin/env bash
set -uo pipefail

USER="$(logname 2>/dev/null || whoami)"
DBPATH="/home/$USER/.local/share/lutris/pga.db"
APIKEY_FILE="$(dirname "$0")/apikey.txt"
SGDB_URL="https://www.steamgriddb.com/api/v2"
BANNER_PATH="/home/$USER/.local/share/lutris/banners/"
COVERART_PATH="/home/$USER/.local/share/lutris/coverart/"
ICON_PATH="/home/$USER/.local/share/icons/hicolor/128x128/apps/"
PREVIEW_DIR="$(mktemp -d /tmp/lutris-preview.XXXXXX)"
trap 'rm -rf "$PREVIEW_DIR"' EXIT

sgdb() { curl -sf -H "Authorization: Bearer $APIKEY" "$@"; }

# --- Menu ---
echo "Lutris Cover Art Downloader"
echo ""
echo "  1) Download covers"
echo "  2) Remove all downloaded covers"
read -rp "Choice [1/2]: " menu_choice

if [[ "$menu_choice" == "2" ]]; then
  rm -f "${BANNER_PATH}"*.png "${COVERART_PATH}"*.png "${ICON_PATH}"lutris_*.png 2>/dev/null
  sqlite3 "$DBPATH" "UPDATE games SET has_custom_banner=0, has_custom_coverart_big=0, has_custom_icon=0;" 2>/dev/null
  echo "All covers removed. Restart Lutris."
  exit 0
fi

echo ""
echo "Cover type:"
echo "  1) Banner (460x215)"
echo "  2) Vertical (600x900)"
echo "  3) Both"
read -rp "Choice [1/2/3]: " choice

case "$choice" in
  1) DIMS=("460x215"); PATHS=("$BANNER_PATH") ;;
  2) DIMS=("600x900"); PATHS=("$COVERART_PATH") ;;
  3) DIMS=("460x215" "600x900"); PATHS=("$BANNER_PATH" "$COVERART_PATH") ;;
  *) echo "Invalid"; exit 1 ;;
esac

for p in "${PATHS[@]}"; do mkdir -p "$p"; done
mkdir -p "$ICON_PATH"

# --- API key ---
if [[ -f "$APIKEY_FILE" ]]; then
  APIKEY="$(cat "$APIKEY_FILE")"
  [[ -z "$APIKEY" ]] && rm -f "$APIKEY_FILE"
fi
if [[ -z "${APIKEY:-}" ]]; then
  echo "SteamGridDB API key needed for vertical covers."
  echo "Get one at: https://www.steamgriddb.com/profile/preferences/api"
  read -rp "API key: " APIKEY
  status=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $APIKEY" "$SGDB_URL/grids/game/1?dimensions=600x900")
  if [[ "$status" != "200" ]]; then echo "Invalid key"; exit 1; fi
  echo "$APIKEY" > "$APIKEY_FILE"
fi
echo ""

# --- Steam search: returns list for fzf, user picks, echo "appid url" ---
steam_pick() {
  local term="$1"
  local encoded
  encoded=$(printf '%s' "$term" | jq -sRr @uri)
  local results
  results=$(curl -sf "https://store.steampowered.com/api/storesearch/?term=$encoded&l=english&cc=US")
  local count
  count=$(echo "$results" | jq '.total // 0')
  if [[ "$count" == "0" || "$count" == "null" ]]; then
    local first
    first=$(echo "$term" | awk '{print $1}')
    encoded=$(printf '%s' "$first" | jq -sRr @uri)
    results=$(curl -sf "https://store.steampowered.com/api/storesearch/?term=$encoded&l=english&cc=US")
    count=$(echo "$results" | jq '.total // 0')
    [[ "$count" == "0" || "$count" == "null" ]] && return 1
  fi
  local list
  list=$(echo "$results" | jq -r '.items[] | "\(.name) (\(.id)) [\(.capsule_image // .header_image // "")]"')
  local picked
  picked=$(echo "$list" | fzf --prompt="Steam > " \
    --preview 'url=$(echo {} | sed -n "s/.*\[\(https\?:\/\/[^]]*\)\].*/\1/p"); if [ -n "$url" ]; then tmp=$(mktemp /tmp/lutris-pv-XXXXXX.png); curl -sf -o "$tmp" "$url" && chafa -f symbols --scale max "$tmp" && rm -f "$tmp"; else echo "(no preview)"; fi' \
    --preview-window=right:50%)
  [[ -z "$picked" ]] && return 1
  local appid header capsule
  appid=$(echo "$picked" | sed 's/.*(\([0-9]*\)).*/\1/')
  header=$(curl -sf "https://store.steampowered.com/api/appdetails?appids=$appid" | jq -r ".\"$appid\".data.header_image // empty")
  capsule=$(curl -sf "https://store.steampowered.com/api/appdetails?appids=$appid" | jq -r ".\"$appid\".data.capsule_image // empty")
  [[ -z "$header" ]] && return 1
  echo "$appid $header ${capsule:-}"
}

# --- SteamGridDB search: returns list for fzf, user picks, echo game_id ---
sgdb_pick() {
  local term="$1"
  local results
  results=$(sgdb "$SGDB_URL/search/autocomplete/$term")
  local count
  count=$(echo "$results" | jq '.data | length // 0')
  if [[ "$count" == "0" || "$count" == "null" ]]; then
    local first
    first=$(echo "$term" | awk '{print $1}')
    results=$(sgdb "$SGDB_URL/search/autocomplete/$first")
    count=$(echo "$results" | jq '.data | length // 0')
    [[ "$count" == "0" || "$count" == "null" ]] && return 1
  fi
  local list
  list=$(echo "$results" | jq -r '.data[] | "\(.name) (\(.id))"')
  local picked
  picked=$(echo "$list" | fzf --prompt="SteamGridDB > ")
  [[ -z "$picked" ]] && return 1
  echo "$picked" | sed 's/.*(\([0-9]*\)).*/\1/'
}

# --- SteamGridDB cover: pick game then pick cover, echo url ---
sgdb_cover() {
  local game_id="$1" dim="$2"
  local grids
  grids=$(sgdb "$SGDB_URL/grids/game/$game_id?dimensions=$dim")
  local count
  count=$(echo "$grids" | jq '.data | length // 0')
  [[ "$count" == "0" || "$count" == "null" ]] && return 1
  local list
  list=$(echo "$grids" | jq -r '.data[] | "\(.width)x\(.height) — \(.url)"')
  local picked
  picked=$(echo "$list" | fzf --prompt="Cover > " \
    --preview 'url=$(echo {} | awk -F" — " "{print \$2}"); if [ -n "$url" ]; then tmp=$(mktemp /tmp/lutris-pv-XXXXXX.png); curl -sf -o "$tmp" "$url" && chafa -f symbols --scale max "$tmp" && rm -f "$tmp"; else echo "(no preview)"; fi' \
    --preview-window=right:50%)
  [[ -z "$picked" ]] && return 1
  echo "$picked" | awk -F' — ' '{print $2}'
}

# --- Main ---
mapfile -t games < <(sqlite3 "$DBPATH" "SELECT slug FROM games;")
[[ ${#games[@]} -eq 0 ]] && { echo "No games in Lutris."; exit 0; }

echo "Pick games (tab to select, enter to confirm):"
echo "  (leave empty and press enter to process all)"
echo ""
mapfile -t picked < <(printf '%s\n' "${games[@]}" "ALL (process all)" | fzf --multi --prompt="Games > " \
  --preview 'slug={}; if [ "$slug" = "ALL (process all)" ]; then echo "Select all games"; elif [ -f "'${BANNER_PATH}'""$slug".png ]; then chafa -f symbols --scale max "'${BANNER_PATH}'""$slug".png; elif [ -f "'${COVERART_PATH}'""$slug".png ]; then chafa -f symbols --scale max "'${COVERART_PATH}'""$slug".png; else echo "(no existing cover)"; fi' \
  --preview-window=right:50%)
if [[ ${#picked[@]} -gt 0 ]]; then
  if printf '%s\n' "${picked[@]}" | grep -q '^ALL (process all)$'; then
    echo "Processing all games."
  else
    games=("${picked[@]}")
  fi
else
  echo "Processing all games."
fi

for slug in "${games[@]}"; do
  all_done=true
  for p in "${PATHS[@]}"; do
    [[ ! -f "${p}${slug}.png" ]] && all_done=false && break
  done
  $all_done && { echo "$slug: already done"; continue; }

  echo ""
  echo "=== $slug ==="

  for i in "${!DIMS[@]}"; do
    [[ -f "${PATHS[$i]}${slug}.png" ]] && continue
    dim="${DIMS[$i]}"
    url=""

    if [[ "$dim" == "460x215" ]]; then
      result=$(steam_pick "$slug") || true
      if [[ -n "$result" ]]; then
        steam_appid=$(echo "$result" | awk '{print $1}')
        url=$(echo "$result" | awk '{print $2}')
        capsule=$(echo "$result" | awk '{print $3}')
      fi
    fi

    if [[ -z "$url" ]]; then
      gid=$(sgdb_pick "$slug") || true
      [[ -n "$gid" ]] && url=$(sgdb_cover "$gid" "$dim") || true
    fi

    if [[ -n "$url" ]]; then
      curl -sf -o "${PATHS[$i]}${slug}.png" "$url"
      echo "Downloaded $dim for $slug"
    else
      echo "Skipped $dim for $slug"
    fi
  done

  if [[ ! -f "${ICON_PATH}lutris_${slug}.png" ]]; then
    icon_url=$(curl -sf "https://lutris.net/api/games/$slug" | jq -r '.icon_url // empty')
    if [[ -n "$icon_url" ]]; then
      curl -sf -o "${ICON_PATH}lutris_${slug}.png" "$icon_url"
    elif [[ -n "${capsule:-}" ]]; then
      curl -sf -o "${ICON_PATH}lutris_${slug}.png" "$capsule"
    fi
  fi

  for i in "${!DIMS[@]}"; do
    [[ -f "${PATHS[$i]}${slug}.png" ]] || continue
    [[ "${DIMS[$i]}" == "460x215" ]] && sqlite3 "$DBPATH" "UPDATE games SET has_custom_banner=1 WHERE slug='$slug';"
    [[ "${DIMS[$i]}" == "600x900" ]] && sqlite3 "$DBPATH" "UPDATE games SET has_custom_coverart_big=1 WHERE slug='$slug';"
  done
  [[ -f "${ICON_PATH}lutris_${slug}.png" ]] && sqlite3 "$DBPATH" "UPDATE games SET has_custom_icon=1 WHERE slug='$slug';"
done

echo ""
echo "Done! Restart Lutris."
