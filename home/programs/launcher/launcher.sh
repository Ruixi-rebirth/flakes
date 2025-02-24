#!/usr/bin/env bash
theme="launcher_theme"
dir="$HOME/.config/rofi"

rofi -no-lazy-grab -show drun -modi drun -theme $dir/"$theme"
