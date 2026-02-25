#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
THEME="$DIR/clipboard_theme.rasi"

# Use Pango markup for styling
# Clear option: Bold red, aligned left with the rest
CLEAR_OPTION="<span foreground='#f38ba8'><b>󰎖  CLEAR ALL HISTORY</b></span>"
# Separator: Heavier line with a brighter color (yellowish) to be clearly visible
SEPARATOR="<span foreground='#f9e2af'>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span>"

# Use the -markup-rows flag directly in the rofi command
# -u 0 marks the first line as "urgent" for potential theme highlights
CHOICE=$( (
    echo "$CLEAR_OPTION"
    echo "$SEPARATOR"
    cliphist list
) | rofi -dmenu -p "󰅍" -theme "$THEME" -markup-rows -u 0)

case "$CHOICE" in
    "$CLEAR_OPTION")
        CONFIRM=$(echo -e "Yes\nNo" | rofi -dmenu -p "Clear all history?" -theme "$THEME")
        if [ "$CONFIRM" == "Yes" ]; then
            cliphist wipe
        fi
        ;;
    "$SEPARATOR"|"")
        exit 0
        ;;
    *)
        # Ensure we only process if it's a valid cliphist item
        if [ -n "$CHOICE" ]; then
            echo "$CHOICE" | cliphist decode | wl-copy
        fi
        ;;
esac
