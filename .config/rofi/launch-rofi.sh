#!/usr/bin/env bash

powermenu="$HOME/.config/rofi/power-menu.sh"

rofi -show drun \
    -modes "drun,calc, power:$powermenu --symbols-font 'Symbols Nerd Font Mono' --choices=shutdown/hibernate/reboot/suspend/logout"
