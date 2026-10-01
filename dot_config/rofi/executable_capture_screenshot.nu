#!/usr/bin/env -S nu --no-config-file

const SCRIPT_PATH = (path self)

def notify-error [message: string] {
  if (which notify-send | is-not-empty) {
    run-external "notify-send" "-u" "critical" "Screenshot failed" $message out> /dev/null err> /dev/null
  }
}

def capture-selection [] {
  if (which slurp | is-empty) {
    notify-error "slurp is required for region selection."
    return
  }
  if (which grim | is-empty) {
    notify-error "grim is required to capture screenshots."
    return
  }

  let selected = (^slurp | complete)
  if $selected.exit_code != 0 {
    return
  }
  let geometry = ($selected.stdout | str trim)
  if $geometry == "" {
    return
  }

  grim -g $geometry -t ppm - | satty -f -
}

def capture-focused [action: string] {
  if (which niri | is-empty) {
    notify-error "niri is required to capture the focused window or screen."
    return
  }
  if (which wl-paste | is-empty) {
    notify-error "wl-paste is required to open Niri screenshots in Satty."
    return
  }

  let result = (^niri msg action $action | complete)
  if $result.exit_code != 0 {
    notify-error "Niri could not capture the screenshot."
    return
  }

  # Niri completes the IPC request before the screenshot reaches the clipboard.
  sleep 150ms
  let types = (^wl-paste --list-types | complete)
  if $types.exit_code != 0 or not ($types.stdout | lines | any {|type| $type == "image/png"}) {
    notify-error "Niri did not provide a screenshot image."
    return
  }

  wl-paste --type image/png | satty -f -
}

def capture [target: string] {
  if (which satty | is-empty) {
    notify-error "satty is required to open screenshots."
    return
  }

  match $target {
    "selection" => { capture-selection }
    "window" => { capture-focused "screenshot-window" }
    "screen" => { capture-focused "screenshot-screen" }
    _ => { notify-error "Unknown screenshot target." }
  }
}

def main [mode?: string, target?: string] {
  if $mode == "capture" {
    if $target == null {
      notify-error "Unknown screenshot target."
      exit 2
    }
    sleep 150ms
    capture $target
    return
  }

  if $mode == null {
    notify-error "Unknown screenshot target."
    exit 2
  }

  match $mode {
    "selection" | "window" | "screen" => {
      ^setsid --fork nu --no-config-file $SCRIPT_PATH "capture" $mode out> /dev/null err> /dev/null
    }
    _ => {
      notify-error "Unknown screenshot target."
      exit 2
    }
  }
}
