#!/usr/bin/env bash

icon=""

# if we use wpctl here it won't stop at 100
# kinda lame solution but whatever
if ! amixer set Master -q 10%+ ; then
    dunstify "Error lowering volume"
else
    status=$(wpctl get-volume @DEFAULT_SINK@)

    volume=$( echo "$status" | awk '{print $2 * 100}')

    if [ -z "$status" ]; then
        dunstify "Error getting volume status"
    elif grep -q 'MUTED' <<< "$status" || [ "$volume" == 0 ]; then
        icon="--raw_icon=$HOME/scripts/volume/volume_x.png"

    elif [ "$volume" -lt 33 ]; then
        icon="--raw_icon=$HOME/scripts/volume/volume.png"

    elif [ "$volume" -gt 33 ] && [ "$volume" -lt 66 ]; then
        icon="--raw_icon=$HOME/scripts/volume/volume_1.png"

    elif [ "$volume" -gt 66 ]; then
        icon="--raw_icon=$HOME/scripts/volume/volume_2.png"
    fi
fi

dunstify "Volume" "$icon" --category='vol' --urgency=low \
    --timeout=1000 --replace=790 --hints=int:value:"$volume"
