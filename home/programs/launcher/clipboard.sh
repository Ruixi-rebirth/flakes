#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
THEME="$DIR/clipboard_theme.rasi"

cliphist list | rofi -dmenu -p "󰅍" -theme "$THEME" | cliphist decode | wl-copy
