#!/usr/bin/env bash

powermenu="$HOME/.config/rofi/power-menu.sh"

rofi -show drun \
    -modes "drun,calc,power:$powermenu --symbols-font 'Symbols Nerd Font Mono' --choices=shutdown/hibernate/reboot/suspend/logout" \
    -qalc-binary='/run/current-system/sw/bin/qalc' \
    -no-drun-show-actions
