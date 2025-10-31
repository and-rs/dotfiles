#!/usr/bin/env bash

icon=""
dotfiles="$HOME/Vault/personal/dotfiles"

if ! wpctl set-volume @DEFAULT_SINK@ 0.05-; then
    dunstify "Error lowering volume"
else
    status=$(wpctl get-volume @DEFAULT_SINK@)

    volume=$( echo "$status" | awk '{print $2 * 100}')

    if [ -z "$status" ]; then
        dunstify "Error getting volume status"
    elif grep -q 'MUTED' <<< "$status" || [ "$volume" == 0 ]; then
        icon="--raw_icon=$dotfiles/scripts/volume/volume_x.png"

    elif [ "$volume" -lt 33 ]; then
        icon="--raw_icon=$dotfiles/scripts/volume/volume.png"

    elif [ "$volume" -gt 33 ] && [ "$volume" -lt 66 ]; then
        icon="--raw_icon=$dotfiles/scripts/volume/volume_1.png"

    elif [ "$volume" -gt 66 ]; then
        icon="--raw_icon=$dotfiles/scripts/volume/volume_2.png"
    fi
fi

dunstify "Volume" "$icon" --category='vol' --urgency=low \
    --timeout=1000 --replace=790 --hints=int:value:"$volume"
