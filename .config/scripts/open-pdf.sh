#!/usr/bin/env bash
set -euo pipefail

DIRS=(
  "$HOME/Zotero/"
  "/mnt/shared/"
  "$HOME/Downloads"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fzf-themes.sh"

pick_file() {
  fd . "${DIRS[@]}" \
    --max-depth=2 \
    --extension djvu --extension epub --extension pdf \
    --full-path \
    | sed "s|^$HOME/|~/|" \
    | sort -uf \
    | fzf "${FZF_THEME_PDF[@]}"
}

if [[ $# -eq 1 ]]; then
  selected=$1
else
  picked=$(pick_file) || exit 0
  [[ -z "$picked" ]] && exit 0
  # Expand ~/ back to $HOME for the real path
  selected="${picked/#\~/$HOME}"
fi

nohup sioyek "$selected" >/dev/null 2>&1 &

