#!/usr/bin/env -S nu --no-config-file

const SCRIPT_DIR = (path self | path dirname)
source ($SCRIPT_DIR | path join "rofi_icons.nu")

const SCREENSHOT_SCRIPT = ($SCRIPT_DIR | path join "capture_screenshot.nu")
const RECORDING_SCRIPT = ($SCRIPT_DIR | path join "capture_recording.nu")

def emit-item [label: string, info: string, icon: string, --disabled] {
  let row = (rofi-row $icon $label)
  let row = if $disabled { $'<span alpha="50%">($row)</span>' } else { $row }
  let options = if $disabled {
    # Rofi has no disabled theme state; active marks our nonselectable rows.
    "info" + (char --integer 31) + $info + (char --integer 31) + "nonselectable" + (char --integer 31) + "true" + (char --integer 31) + "active" + (char --integer 31) + "true"
  } else {
    "info" + (char --integer 31) + $info
  }
  print -n ($row + (char nul) + $options + (char newline))
}

def metadata [key: string, value: string] {
  print -n ((char nul) + $key + (char --integer 31) + $value + (char newline))
}

def show-context [workspace: record] {
  let position = $"Position ($workspace.idx) · ($workspace.output)"
  let context = if $workspace.name != null and $workspace.name != "" {
    $"Workspace ($workspace.name) · ($position)"
  } else {
    $position
  }
  metadata "message" (rofi-row "screen" $context --no-icon)
}

def show-niri-actions [] {
  let workspaces = (niri msg --json workspaces | from json)
  let workspace = ($workspaces | where is_focused | get -o 0)
  if $workspace == null {
    metadata "message" ""
    emit-item "No active workspace" "unavailable" "screen" --disabled
    return
  }
  show-context $workspace

  # Rofi can hold keyboard focus; use the workspace's active window instead.
  let window = (niri msg --json windows | from json | where id == $workspace.active_window_id | get -o 0)
  if $window == null {
    emit-item "No window to float or tile" "unavailable" "window" --disabled
  } else if $window.is_floating {
    emit-item "Tile window" $"tile|($window.id)" "window"
  } else {
    emit-item "Float window" $"float|($window.id)" "window"
  }

  let other_monitors = (active-outputs | any {|output| $output.name != $workspace.output })
  let monitor_label = if $other_monitors { "Move workspace to monitor" } else { "Move workspace to monitor (no other monitors)" }
  emit-item $monitor_label "monitors" "screen" --disabled=(not $other_monitors)

  let can_move_up = $workspace.idx > 1
  let up_label = if $can_move_up { "Move workspace up" } else { "Move workspace up (already first)" }
  emit-item $up_label "up" "window" --disabled=(not $can_move_up)

  let can_move_down = ($workspaces | any {|ws| $ws.output == $workspace.output and $ws.idx > $workspace.idx })
  let down_label = if $can_move_down { "Move workspace down" } else { "Move workspace down (already last)" }
  emit-item $down_label "down" "window" --disabled=(not $can_move_down)
}

def recording-active [] {
  let status = (run-external $RECORDING_SCRIPT "status" | complete)
  $status.exit_code == 0 and ($status.stdout | str trim) == "active"
}

def show-root [] {
  metadata "prompt" "Desktop"
  show-niri-actions
  emit-item "Screenshot" "screenshots" "screenshot"
  if (recording-active) {
    emit-item "Stop recording" "stop-recording" "recording"
  } else {
    emit-item "Screen recording" "recordings" "recording"
  }
}

def show-screenshots [] {
  metadata "prompt" "Screenshot"
  metadata "message" ""
  emit-item "Selection" "screenshot|selection" "selection"
  emit-item "Focused window" "screenshot|window" "window"
  emit-item "Focused screen" "screenshot|screen" "screen"
  emit-item "Back" "root" "back"
}

def show-recordings [] {
  metadata "prompt" "Screen recording"
  metadata "message" ""
  if (recording-active) {
    emit-item "Stop recording" "stop-recording" "recording"
  } else {
    emit-item "Selection" "record|selection" "selection"
    emit-item "Window (pick in portal)" "record|window" "window"
    emit-item "Focused screen" "record|screen" "screen"
  }
  emit-item "Back" "root" "back"
}

def show-audio-choices [target: string] {
  metadata "prompt" "Recording audio"
  metadata "message" ""
  emit-item "No audio" $"start|($target)|none" "no_audio"
  emit-item "Desktop audio" $"start|($target)|desktop" "desktop_audio"
  emit-item "Microphone" $"start|($target)|mic" "microphone"
  emit-item "Desktop + microphone" $"start|($target)|both" "mixed_audio"
  emit-item "Back" "recordings" "back"
}

def active-outputs [] {
  niri msg --json outputs | from json | values | where logical != null | sort-by name
}

def show-monitors [] {
  metadata "prompt" "Move workspace"
  let workspace = (niri msg --json workspaces | from json | where is_focused | get -o 0)
  if $workspace == null {
    show-root
    return
  }
  show-context $workspace
  let outputs = (active-outputs | where name != $workspace.output)
  if ($outputs | is-empty) {
    metadata "message" "No other active monitors connected."
  }
  for output in $outputs {
    emit-item $"($output.name): ($output.make) ($output.model)" $"monitor|($output.name)" "screen"
  }
  emit-item "Back" "root" "back"
}

def run-action [args: list<string>] {
  let result = (niri msg action ...$args | complete)
  if $result.exit_code != 0 {
    print --stderr ($result.stderr | str trim)
    show-root
    metadata "message" "Niri could not perform the action."
  }
}

def main [...args: string] {
  let state = ($env.ROFI_RETV? | default "0" | into int)
  if $state not-in [0 1] { return }
  metadata "no-custom" "true"
  metadata "markup-rows" "true"
  let selection = if $state == 0 { "" } else { $env.ROFI_INFO? | default "" }

  match $selection {
    "" | "root" => { show-root }
    "screenshots" => { show-screenshots }
    "recordings" => { show-recordings }
    "screenshot|selection" | "screenshot|window" | "screenshot|screen" => {
      let target = ($selection | split row "|" | get 1)
      run-external $SCREENSHOT_SCRIPT $target out> /dev/null err> /dev/null
    }
    "record|selection" | "record|window" | "record|screen" => {
      show-audio-choices ($selection | split row "|" | get 1)
    }
    "stop-recording" => {
      run-external $RECORDING_SCRIPT "stop" out> /dev/null err> /dev/null
      show-root
    }
    _ if ($selection | str starts-with "start|") => {
      let choice = ($selection | split row "|")
      if ($choice | length) == 3 and $choice.1 in [selection window screen] and $choice.2 in [none desktop mic both] {
        run-external $RECORDING_SCRIPT "start" $choice.1 $choice.2 out> /dev/null err> /dev/null
      } else {
        show-root
      }
    }
    _ if ($selection | str starts-with "float|") => {
      run-action ["move-window-to-floating" "--id" ($selection | str replace "float|" "")]
    }
    _ if ($selection | str starts-with "tile|") => {
      run-action ["move-window-to-tiling" "--id" ($selection | str replace "tile|" "")]
    }
    "up" => { run-action ["move-workspace-up"] }
    "down" => { run-action ["move-workspace-down"] }
    "monitors" => { show-monitors }
    _ if ($selection | str starts-with "monitor|") => {
      let output = ($selection | str replace "monitor|" "")
      if $output in (active-outputs | get name) {
        run-action ["move-workspace-to-monitor" $output]
      } else {
        show-monitors
        metadata "message" "That monitor disconnected. Choose another destination."
      }
    }
    _ => { show-root }
  }
}
