#!/bin/bash
tf=$(mktemp)
yazi --chooser-file="$tf"
selected=$(cat "$tf" 2>/dev/null)
rm -f "$tf"

if [[ -n "$selected" ]]; then
  target="$selected"
  [[ ! -d "$target" ]] && target=$(dirname "$selected")
  name=$(basename "$target" | tr . _)
  tmux new-session -d -s "$name" -c "$target" 2>/dev/null
  tmux switch-client -t "$name"
fi
