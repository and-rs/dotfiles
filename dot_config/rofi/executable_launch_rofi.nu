#!/usr/bin/env -S nu --no-config-file

const SCRIPT_DIR = (path self | path dirname)
let power_menu = ($SCRIPT_DIR | path join "power_menu.nu")
let desktop_menu = ($SCRIPT_DIR | path join "desktop_menu.nu")
let modes = $"drun,desktop:($desktop_menu),calc,power:($power_menu) --choices=shutdown/hibernate/reboot/suspend/logout"
let plugin_dir = ($SCRIPT_DIR | path join "plugins")
let existing = ($env.ROFI_PLUGIN_PATH? | default "")
let plugin_path = if $existing == "" {
  $plugin_dir
} else {
  $"($plugin_dir):($existing)"
}

let cache_dir = ($env.XDG_CACHE_HOME? | default --empty ($env.HOME | path join ".cache"))
let state_file = ($cache_dir | path join "rofi" "last-mode")
let saved = try { open --raw $state_file | str trim } catch { "" }
let initial = if $saved in [drun desktop calc power] { $saved } else { "drun" }

with-env {ROFI_PLUGIN_PATH: $plugin_path ROFI_LAST_MODE_FILE: $state_file} {
  rofi -show $initial -modes $modes -no-drun-show-actions
}
