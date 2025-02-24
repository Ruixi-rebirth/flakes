#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
THEME="$DIR/clipboard_theme.rasi"

# Clear option: Bold red, aligned left with the rest
CLEAR_OPTION="󰎖  CLEAR ALL HISTORY"
# Separator: Heavier line with a brighter color (yellowish) to be clearly visible
SEPARATOR="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Use -u 0 to mark first line as urgent, -a 1 for second line as active
CHOICE=$( (
  echo "$CLEAR_OPTION"
  echo "$SEPARATOR"
  cliphist list
) | rofi -dmenu -p "󰅍" -theme "$THEME" -u 0 -a 1)

case "$CHOICE" in
"$CLEAR_OPTION")
  CONFIRM=$(echo -e "Yes\nNo" | rofi -dmenu -p "Clear history and reset IDs?" -theme "$THEME")
  if [ "$CONFIRM" == "Yes" ]; then
    cliphist wipe
    rm -rf ~/.cache/cliphist/
  fi
  ;;
"$SEPARATOR" | "")
  exit 0
  ;;
*)
  # Ensure we only process if it's a valid cliphist item
  if [ -n "$CHOICE" ]; then
    echo "$CHOICE" | cliphist decode | wl-copy
  fi
  ;;
esac
