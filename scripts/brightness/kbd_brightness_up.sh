#!/usr/bin/env bash

brightnessctl -q --device=asus::kbd_backlight set +33%

brightness="$(brightnessctl --device=asus::kbd_backlight get)"

percentage=$((brightness * 100 / 3))

notify-send "Keyboard brightness" "Level: $brightness" \
    -h int:value:"$percentage" \
    -u low \
    -t 1000 \
    -r 799
