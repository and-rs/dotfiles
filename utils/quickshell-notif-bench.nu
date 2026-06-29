#!/usr/bin/env nu

def main [--delay: int = 300, --log: string = ""] {
  let log_path = if ($log | is-empty) {
    ($env.HOME | path join ".cache/quickshell-notification-v2-bench.log")
  } else {
    ($log | path expand)
  }

  mkdir ($log_path | path dirname)
  print $"→ quickshell log: ($log_path)"

  let launch = ($env.HOME | path join ".config/quickshell/launch.sh")
  let pid = (^bash -lc $"setsid env QS_NOTIF_DEBUG=1 ($launch) > ($log_path) 2>&1 & echo $!" | str trim)
  print $"→ quickshell process group: ($pid)"
  sleep 1500ms

  nu utils/test-notifs.nu --img --delay $delay
  sleep 1500ms

  print "→ NotificationV2 log lines"
  ^bash -lc $"grep -aE '\\[NotificationV2\\]|Cannot open|image' ($log_path) | tail -n 80 || true"

  if ($pid | is-not-empty) {
    ^bash -lc "kill -TERM -- -$1 2>/dev/null; sleep 0.2; kill -KILL -- -$1 2>/dev/null || true" sh $pid | ignore
  }
}
