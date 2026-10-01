#!/usr/bin/env -S nu --no-config-file

def notify-error [message: string] {
  if (which notify-send | is-not-empty) {
    run-external "notify-send" "-u" "critical" "Screenshot failed" $message out> /dev/null err> /dev/null
  }
}

def main [target?: string] {
  let action = match $target {
    "selection" => "screenshot"
    "window" => "screenshot-window"
    "screen" => "screenshot-screen"
    _ => {
      notify-error "Unknown screenshot target."
      exit 2
    }
  }

  # Rofi stays mapped until the script it spawned exits, so firing the niri
  # screenshot action synchronously makes niri's overlay (or an instant
  # window/screen capture) appear while rofi is still on screen. Launch the
  # action detached with a brief delay and return immediately: the script
  # exits, rofi tears down its layer-surface, and only then does niri act.
  ^setsid --fork nu --no-config-file -c $"sleep 150ms; niri msg action ($action)" out> /dev/null err> /dev/null
}
