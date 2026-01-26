#!/usr/bin/env bash

brightnessctl -q set 5%-

brightness="$(brightnessctl get)"

percentage=$((brightness * 100 / 19200))

notify-send "Brightness" "$percentage%" -u low -t 1000 -r 798 -h int:value:"$percentage"
