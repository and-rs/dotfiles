#!/usr/bin/env bash

icon_path=""
message="Unknown error"
dotfiles="$HOME/Vault/personal/dotfiles"

if ! wpctl set-mute @DEFAULT_SOURCE@ toggle; then
    message="Error toggling mute"
else
    volume_info=$(wpctl get-volume @DEFAULT_SOURCE@)

    if [ -z "$volume_info" ]; then
        message="Error getting volume status"
    elif grep -q 'MUTED' <<< "$volume_info"; then
        icon_path="$dotfiles/scripts/volume/mic_off.png"
        message="MUTED"
    else
        icon_path="$dotfiles/scripts/volume/mic_on.png"
        message="ON"
    fi
fi

notify-send "Microphone" "$message" -i "$icon_path" -u low -t 1000 -r 798
