#!/usr/bin/env -S nu --no-config-file

const SCRIPT_DIR = (path self | path dirname)
let power_menu = ($SCRIPT_DIR | path join "power_menu.nu")
let capture_menu = ($SCRIPT_DIR | path join "capture_menu.nu")
let modes = $"drun,capture:($capture_menu),calc,power:($power_menu) --choices=shutdown/hibernate/reboot/suspend/logout"

rofi -show drun -modes $modes -no-drun-show-actions
