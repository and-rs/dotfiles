#!/usr/bin/env bash

CONFIG_FILES="$HOME/.config/waybar/config.jsonc $HOME/.config/waybar/style.css $HOME/.config/waybar/modules.jsonc"

trap "pkill waybar" EXIT

while true; do
    waybar -l debug &
    inotifywait -e create,modify $CONFIG_FILES
    pkill waybar
done
