#!/usr/bin/env bash

powermenu="$HOME/.config/rofi/power-menu.sh"

rofi -show drun \
    -modes "drun,calc,power:$powermenu -qalc-binary='/run/current-system/sw/bin/qalc' --symbols-font 'Symbols Nerd Font Mono' --choices=shutdown/hibernate/reboot/suspend/logout"
