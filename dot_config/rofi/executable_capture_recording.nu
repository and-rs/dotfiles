#!/usr/bin/env -S nu --no-config-file

def state-dir [] {
  let runtime = ($env.XDG_RUNTIME_DIR? | default "")
  if $runtime != "" {
    $runtime | path join "rofi-capture"
  } else {
    let temp = ($env.TMPDIR? | default "/tmp")
    let uid = (^id -u | str trim)
    $temp | path join $"rofi-capture-($uid)"
  }
}

def pid-file [] {
  state-dir | path join "recording.pid"
}

def output-file [] {
  state-dir | path join "recording.output"
}

def log-file [] {
  state-dir | path join "recording.log"
}

def ensure-state-dir [] {
  try {
    mkdir (state-dir)
    ^chmod 700 (state-dir)
  } catch {
    notify "-u" "critical" "Screen recording failed" "Could not create the recording state directory."
    exit 1
  }
}

def notify [...arguments: string] {
  if (which notify-send | is-not-empty) {
    run-external "notify-send" ...$arguments out> /dev/null err> /dev/null
  }
}

def clear-state [] {
  rm --force (pid-file) (output-file)
}

# Process *name* match for gpu-screen-recorder. We match the name (/proc/comm),
# NOT the full command line: `pgrep -f` would also match shells, editors, or
# this very script whenever the string "gpu-screen-recorder" merely appears in
# their arguments. The kernel truncates comm to 15 chars, so the longest
# reliable, anchored name prefix is "gpu-screen-reco".
const RECORDER_NAME = "^gpu-screen-reco"

# Source of truth for "is a recording running": the live process list, matched
# by process name. Returns a list<int> of PIDs (empty when nothing is running).
def recorder-pids [] {
  if (which pgrep | is-empty) {
    return []
  }
  let result = (^pgrep $RECORDER_NAME | complete)
  if $result.exit_code != 0 {
    return []
  }
  $result.stdout
  | lines
  | each {|line| $line | str trim }
  | where {|line| $line != "" }
  | each {|line| try { $line | into int } catch { null } }
  | compact
}

# The recorded output path, if the state file recorded one. Advisory only --
# never used to decide whether a recording is active.
def recorded-output [] {
  try {
    open (output-file) | str trim
  } catch {
    ""
  }
}

def recording-active [] {
  not ((recorder-pids) | is-empty)
}

# Full command line of a PID (nul-separated argv joined with spaces), or "".
def pid-cmdline [pid: int] {
  try {
    open --raw $"/proc/($pid)/cmdline" | decode utf-8 | str replace --all (char nul) " "
  } catch {
    ""
  }
}

def status [] {
  if (recording-active) {
    print "active"
  } else {
    clear-state
    print "idle"
  }
}

def require-command [command: string, error: string] {
  if (which $command | is-empty) {
    notify "-u" "critical" "Screen recording failed" $error
    exit 1
  }
}

def start [target: string, audio: string] {
  if (recording-active) {
    notify "-u" "critical" "Screen recording already active"
    exit 1
  }
  ensure-state-dir
  clear-state
  require-command "gpu-screen-recorder" "gpu-screen-recorder is not available."

  let capture = match $target {
    "selection" => {
      require-command "slurp" "slurp is required for region selection."
      let selected = (^slurp | complete)
      if $selected.exit_code != 0 {
        return
      }
      let region = ($selected.stdout | str trim)
      let geometry = ($region | parse --regex '^(?<x>-?[0-9]+),(?<y>-?[0-9]+)\s+(?<width>[0-9]+)x(?<height>[0-9]+)$')
      if ($geometry | is-empty) {
        notify "-u" "critical" "Screen recording failed" "slurp returned invalid selection geometry."
        exit 1
      }
      let coordinates = ($geometry | first)
      {
        name: "region"
        arguments: ["-w" "region" "-region" $"($coordinates.width)x($coordinates.height)+($coordinates.x)+($coordinates.y)"]
      }
    }
    "window" => {
      {name: "portal" arguments: ["-w" "portal"]}
    }
    "screen" => {
      require-command "niri" "Could not determine the focused screen."
      let focused = (^niri msg --json focused-output | complete)
      let output_name = try {
        $focused.stdout | from json | get name
      } catch {
        ""
      }
      if $focused.exit_code != 0 or $output_name == "" {
        notify "-u" "critical" "Screen recording failed" "Could not determine the focused screen."
        exit 1
      }
      let monitors = (^gpu-screen-recorder --list-monitors | complete)
      let supported = ($monitors.stdout | lines | any {|line|
        ($line | split row "|" | first | str trim) == $output_name
      })
      if $monitors.exit_code != 0 or not $supported {
        notify "-u" "critical" "Screen recording failed" $"GPU Screen Recorder cannot capture ($output_name)."
        exit 1
      }
      {name: $output_name arguments: ["-w" $output_name]}
    }
    _ => {
      notify "-u" "critical" "Screen recording failed" "Unknown capture target."
      exit 2
    }
  }

  let audio_sources = match $audio {
    "none" => ""
    "desktop" => "default_output"
    "mic" => "default_input"
    "both" => "default_output|default_input"
    _ => {
      notify "-u" "critical" "Screen recording failed" "Unknown audio option."
      exit 2
    }
  }

  let output_dir = ($env.XDG_VIDEOS_DIR? | default ($env.HOME | path join "Videos"))
  try {
    mkdir $output_dir
  } catch {
    notify "-u" "critical" "Screen recording failed" $"Could not create ($output_dir)."
    exit 1
  }
  let timestamp = (date now | format date "%Y-%m-%d_%H-%M-%S")
  let output_path = ($output_dir | path join $"screenrecording-($timestamp)-($nu.pid).mp4")
  let base_args = ($capture.arguments | append ["-f" "60" "-k" "h264" "-encoder" "gpu" "-fallback-cpu-encoding" "yes" "-o" $output_path])
  let recorder_args = if $audio_sources != "" {
    $base_args | append ["-a" $audio_sources "-ac" "aac"]
  } else {
    $base_args
  }

  let _job = (job spawn {
    ^setsid --fork gpu-screen-recorder ...$recorder_args out+err> (log-file)
  })

  mut pid = null
  for attempt in 0..49 {
    $pid = (recorder-pids | where {|candidate| (pid-cmdline $candidate) | str contains $output_path } | first | default null)
    if $pid != null {
      break
    }
    sleep 100ms
  }

  if $pid == null {
    let log = try {
      open (log-file) | lines | last 3 | str join "\n"
    } catch {
      ""
    }
    let detail = if ($log | str contains "gsr-kms-server is missing sys_admin cap") {
      "KMS permission is missing. Enable GPU Screen Recorder's gsr-kms-server capability; Rofi cannot use terminal authentication."
    } else if $log != "" {
      $log
    } else {
      "Recorder exited before capture started."
    }
    clear-state
    notify "-u" "critical" "Screen recording failed" $detail
    exit 1
  }

  $"($pid)\n" | save --force (pid-file)
  $"($output_path)\n" | save --force (output-file)
  ^chmod 600 (pid-file) (output-file)
  if $capture.name == "portal" {
    notify "Choose a window in the screen-capture dialog" $output_path
  } else {
    notify "Screen recording started" $output_path
  }
}

def stop [] {
  let pids = (recorder-pids)
  if ($pids | is-empty) {
    clear-state
    notify "-u" "critical" "No Rofi screen recording is active"
    exit 1
  }

  # Advisory: remember where the file should be before we tear down state.
  let output_path = (recorded-output)

  # SIGINT lets gpu-screen-recorder finalize the MP4 (flush buffers, write the
  # moov atom). A plain TERM/KILL would truncate the file. Match by process
  # name (not -f) to avoid signalling unrelated processes.
  if (which pkill | is-not-empty) {
    ^pkill -INT $RECORDER_NAME
  } else {
    $pids | each {|pid| ^kill -INT $pid }
  }

  for attempt in 0..199 {
    if not (recording-active) {
      clear-state
      if $output_path != "" and ($output_path | path exists) and ((ls $output_path | get size.0) > 0b) {
        notify "Screen recording saved" $output_path
      } else {
        notify "-u" "critical" "Screen recording stopped" "No video file was produced."
      }
      return
    }
    sleep 100ms
  }

  notify "-u" "critical" "Screen recording is still stopping" "The recorder did not exit yet; its state was kept."
  exit 1
}

def main [action?: string, target?: string, audio?: string] {
  let action = ($action | default "")
  match $action {
    "status" => { status }
    "start" => {
      if $target == null or $audio == null {
        notify "-u" "critical" "Screen recording failed" "Usage: capture_recording.nu start TARGET AUDIO"
        exit 2
      }
      start $target $audio
    }
    "stop" => { stop }
    _ => {
      print -e "Usage: capture_recording.nu {status|start TARGET AUDIO|stop}"
      exit 2
    }
  }
}
