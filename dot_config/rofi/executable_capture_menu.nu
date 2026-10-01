#!/usr/bin/env -S nu --no-config-file

const SCRIPT_DIR = (path self | path dirname)
source ($SCRIPT_DIR | path join "rofi_icons.nu")

let screenshot_script = ($SCRIPT_DIR | path join "capture_screenshot.nu")
let recording_script = ($SCRIPT_DIR | path join "capture_recording.nu")


def emit-item [label: string, info: string, icon?: string] {
  let text = if $icon == null {
    $label
  } else {
    rofi-row $icon $label
  }
  print -n ($text + (char nul) + "info" + (char --integer 31) + $info + (char newline))
}

def show-root [] {
  print -n ((char nul) + "prompt" + (char --integer 31) + "Capture" + (char newline))
  emit-item "Screenshot" "screenshots" "screenshot"
  emit-item "Screen recording" "recordings" "recording"
}

def show-screenshots [] {
  print -n ((char nul) + "prompt" + (char --integer 31) + "Screenshot" + (char newline))
  emit-item "Selection" "screenshot|selection" "selection"
  emit-item "Focused window" "screenshot|window" "window"
  emit-item "Focused screen" "screenshot|screen" "screen"
  emit-item "Back" "root" "back"
}

def show-recordings [] {
  print -n ((char nul) + "prompt" + (char --integer 31) + "Screen recording" + (char newline))
  let status = (run-external $recording_script "status" | complete)
  if ($status.stdout | str trim) == "active" {
    emit-item "Stop recording" "stop-recording" "recording"
  } else {
    emit-item "Selection" "record|selection" "selection"
    emit-item "Window (pick in portal)" "record|window" "window"
    emit-item "Focused screen" "record|screen" "screen"
  }
  emit-item "Back" "root" "back"
}

def show-audio-choices [target: string] {
  print -n ((char nul) + "prompt" + (char --integer 31) + "Recording audio" + (char newline))
  emit-item "No audio" $"start|($target)|none" "no_audio"
  emit-item "Desktop audio" $"start|($target)|desktop" "desktop_audio"
  emit-item "Microphone" $"start|($target)|mic" "microphone"
  emit-item "Desktop + microphone" $"start|($target)|both" "mixed_audio"
  emit-item "Back" "recordings" "back"
}

def main [...args: string] {
  print -n ((char nul) + "no-custom" + (char --integer 31) + "true" + (char newline))
  print -n ((char nul) + "markup-rows" + (char --integer 31) + "true" + (char newline))

  let selection = ($env.ROFI_INFO? | default ($args | first | default ""))

  match $selection {
    "" | "root" => { show-root }
    "screenshots" => { show-screenshots }
    "recordings" => { show-recordings }
    "screenshot|selection" => {
      run-external $screenshot_script "selection" out> /dev/null err> /dev/null
    }
    "screenshot|window" => {
      run-external $screenshot_script "window" out> /dev/null err> /dev/null
    }
    "screenshot|screen" => {
      run-external $screenshot_script "screen" out> /dev/null err> /dev/null
    }
    "record|selection" => { show-audio-choices "selection" }
    "record|window" => { show-audio-choices "window" }
    "record|screen" => { show-audio-choices "screen" }
    "stop-recording" => {
      run-external $recording_script "stop" out> /dev/null err> /dev/null
      show-recordings
    }
    _ if ($selection | str starts-with "start|") => {
      let choice = ($selection | split row "|")
      if ($choice | length) == 3 {
        run-external $recording_script "start" $choice.1 $choice.2 out> /dev/null err> /dev/null
      } else {
        show-root
      }
    }
    _ => { show-root }
  }
}
