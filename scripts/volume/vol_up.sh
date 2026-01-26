#!/usr/bin/env bash

icon_path=""
dotfiles="$HOME/Vault/personal/dotfiles"

# if we use wpctl here it won't stop at 100
# kinda lame solution but whatever
if ! amixer set Master -q 5%+ ; then
    notify-send "Error lowering volume"
else
    status=$(wpctl get-volume @DEFAULT_SINK@)

    volume=$( echo "$status" | awk '{print $2 * 100}')

    if [ -z "$status" ]; then
        notify-send "Error getting volume status"
    elif grep -q 'MUTED' <<< "$status" || [ "$volume" == 0 ]; then
        icon_path="$dotfiles/scripts/volume/volume_x.png"

    elif [ "$volume" -lt 33 ]; then
        icon_path="$dotfiles/scripts/volume/volume.png"

    elif [ "$volume" -gt 33 ] && [ "$volume" -lt 66 ]; then
        icon_path="$dotfiles/scripts/volume/volume_1.png"

    elif [ "$volume" -gt 66 ]; then
        icon_path="$dotfiles/scripts/volume/volume_2.png"
    fi
fi

notify-send "Volume" -i "$icon_path" -c vol -u low \
    -t 1000 -r 790 -h int:value:"$volume"
