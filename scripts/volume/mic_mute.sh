#!/usr/bin/env bash

message="Unknown error"
icon=""

if ! wpctl set-mute @DEFAULT_SOURCE@ toggle; then
    message="Error toggling mute"
else
    volume_info=$(wpctl get-volume @DEFAULT_SOURCE@)

    if [ -z "$volume_info" ]; then
        message="Error getting volume status"
    elif grep -q 'MUTED' <<< "$volume_info"; then
        icon="--raw_icon=$HOME/scripts/volume/mic_off.png"
        message="MUTED"
    else
        icon="--raw_icon=$HOME/scripts/volume/mic_on.png"
        message="ON"
    fi
fi

dunstify "Microphone" --urgency=low --timeout=1000 --replace=798 "$icon" "$message"
