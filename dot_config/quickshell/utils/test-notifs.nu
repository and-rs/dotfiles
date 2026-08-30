#!/usr/bin/env nu

const script_dir = (path self | path dirname)

# Fires a batch of test notifications to exercise the notification stack.
# Usage: nu test-notifs.nu [--delay <ms>] [--img] [--count <notifications>] [--massive] [--persistent] [--timeouts] [--burst]

def send [
  summary: string
  --body: string = ""
  --app: string = "test-notifs"
  --icon: string = ""
  --urgency: string = "normal"
] {
  mut args: list<string> = [--app-name $app --urgency $urgency]

  if ($icon | is-not-empty) {
    $args = ($args | append [--icon $icon])
  }

  if ($body | is-not-empty) {
    ^notify-send ...$args $summary $body
  } else {
    ^notify-send ...$args $summary
  }
}

def dbus-notify [
  app: string
  summary: string
  body: string
  actions: list<string>
  hints: list<string>
  timeout: int
] {
  let hint_count = (($hints | length) / 3 | into int)
  ^busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications Notify susssasa{sv}i $app 0 "" $summary $body ($actions | length) ...$actions $hint_count ...$hints $timeout | ignore
}

def print-capabilities [] {
  print "→ server capabilities"
  ^busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications GetCapabilities
}

def send-image-cases [img: string, delay: int] {
  print $"→ image icon path: ($img)"
  send "Image icon path" --body "Image comes from notify-send icon path." --app "test-image-icon" --icon $img --urgency normal
  sleep ($delay * 1ms)

  print $"→ image-path hint: ($img)"
  dbus-notify test-image-hint "Image path hint" "Image comes from image-path hint." [] [image-path s $img] 7000
  sleep ($delay * 1ms)

  let tmp = (mktemp --suffix .png)
  cp $img $tmp
  print $"→ temp image-path hint deleted after send: ($tmp)"
  dbus-notify test-image-temp "Temp image hint" "Source file gets deleted after notification send. Cache must keep image alive." [] [image-path s $tmp] 7000
  sleep 100ms
  rm -f $tmp
  sleep ($delay * 1ms)
}

def send-scroll-cases [count: int, delay: int] {
  for index in 1..$count {
    send $"Scroll test ($index)/($count)" --body "This notification verifies that the sidebar can reach both bounds with a long history." --app "test-scroll" --urgency normal
    sleep ($delay * 1ms)
  }
}

def send-massive-case [delay: int] {
  for index in 1..6 {
    send $"Comparison short notification ($index)/12" --body "This normal-height notification provides a scrollbar movement baseline around the massive entry." --app "test-massive-scroll" --urgency normal
    sleep ($delay * 1ms)
  }

  let paragraph = "This deliberately oversized plain-text notification body verifies that the sidebar preview remains capped instead of laying out every line. Compare its card height and scroll behavior with the surrounding short notifications."
  let body = (1..300 | each {|index| $"Section ($index): ($paragraph)" } | str join "\n\n")
  send "Massive sidebar scroll test" --body $body --app "test-massive-scroll" --urgency normal
  sleep ($delay * 1ms)

  for index in 7..12 {
    send $"Comparison short notification ($index)/12" --body "This normal-height notification provides a scrollbar movement baseline around the massive entry." --app "test-massive-scroll" --urgency normal
    sleep ($delay * 1ms)
  }
}

def send-timeout-cases [delay: int] {
  print "→ server-default timeout (-1)"
  dbus-notify test-timeout-default "Server default timeout" "Should use the configured popup duration." [] [] -1
  sleep ($delay * 1ms)

  print "→ short timeout (1000ms)"
  dbus-notify test-timeout-short "Short timeout" "Should expire after one second, without a three-second minimum." [] [] 1000
  sleep ($delay * 1ms)

  print "→ persistent timeout (0)"
  dbus-notify test-timeout-persistent "Persistent notification" "The popup has no progress bar and remains until dismissed." [] [] 0
}

def send-persistent-case [] {
  dbus-notify test-timeout-persistent "Persistent notification" "This popup has no progress bar and remains until dismissed." [] [] 0
}

def main [--delay: int = 300, --img, --count: int = 0, --massive, --persistent, --timeouts, --burst] {
  let image_path = ($script_dir | path join "../../../wallpapers/stars.png" | path expand)

  if $img {
    send-image-cases $image_path $delay
    print "done — image notifications sent"
    return
  }

  if $persistent {
    print "→ persistent timeout (0)"
    send-persistent-case
    print "done - persistent notification sent; dismiss it manually"
    return
  }

  if $timeouts {
    send-timeout-cases $delay
    print "done - timeout notifications sent; the persistent popup appears after the default and short popups expire"
    return
  }

  if $burst {
    send-scroll-cases 50 0
    print "done - 50 burst notifications sent"
    return
  }

  if $count > 0 {
    send-scroll-cases $count $delay
    print $"done - ($count) scroll-test notifications sent"
    return
  }

  if $massive {
    print "→ massive body with short comparison notifications"
    send-massive-case $delay
    print "done - 12 short and 1 massive scroll-test notifications sent"
    return
  }

  let cases: list<record> = [
    {
      label: "plain summary only"
      summary: "Build finished"
      body: ""
      app: "cargo"
      icon: "utilities-terminal"
      urgency: "normal"
    }
    {
      label: "summary + short body"
      summary: "Download complete"
      body: "archlinux-2026.iso has finished downloading."
      app: "firefox"
      icon: "firefox"
      urgency: "normal"
    }
    {
      label: "long body (tests popup/sidebar wrap limits)"
      summary: "System update available"
      body: "The following packages have updates: linux-firmware, mesa, pipewire, niri, quickshell. Review the changelog before upgrading. Some packages may require a reboot to take effect. Run `sudo nixos-rebuild switch` to apply."
      app: "packagekit"
      icon: ""
      urgency: "low"
    }
    {
      label: "long summary (tests elide)"
      summary: "This is an extremely long notification summary that should get elided at the end"
      body: ""
      app: "test"
      icon: ""
      urgency: "normal"
    }
    {
      label: "critical urgency"
      summary: "Battery critically low"
      body: "5% remaining. Plug in now."
      app: "upower"
      icon: ""
      urgency: "critical"
    }
    {
      label: "no icon (tests IconFallback letter)"
      summary: "Spotify"
      body: "Now playing: Daft Punk — Get Lucky"
      app: "Spotify"
      icon: ""
      urgency: "normal"
    }
    {
      label: "low urgency, no body"
      summary: "Sync complete"
      body: ""
      app: "nextcloud"
      icon: ""
      urgency: "low"
    }
    {
      label: "image path (tests NotificationCard image render)"
      summary: "Photo uploaded"
      body: "stars.png was uploaded successfully."
      app: "gallery"
      icon: $image_path
      urgency: "normal"
    }
  ]

  for c in $cases {
    print $"→ ($c.label)"
    send $c.summary --body $c.body --app $c.app --icon $c.icon --urgency $c.urgency
    sleep ($delay * 1ms)
  }

  print-capabilities
  sleep ($delay * 1ms)

  print "→ actions (tests actionsSupported + action buttons)"
  dbus-notify test-actions "Action buttons" "Click Open, Snooze, or Dismiss in popup or notification menu." [default Open snooze Snooze dismiss Dismiss] [] 10000
  sleep ($delay * 1ms)

  print "→ inline reply (tests inlineReplySupported + input box)"
  dbus-notify test-reply "Inline reply" "Reply box should appear. Type text, press Enter or Send." [inline-reply "Type reply..."] [] 12000
  sleep ($delay * 1ms)

  print "→ markup + hyperlinks (tests advertised body markup/hyperlinks)"
  dbus-notify test-markup "Markup body" "<b>Bold</b> <i>italic</i> <a href='https://example.com'>link</a>" [] [] 7000
  sleep ($delay * 1ms)

  print "→ image hint (tests image-path hint)"
  dbus-notify test-image-hint "Image hint" "Image comes from image-path hint, not icon." [] [image-path s $image_path] 7000
  sleep ($delay * 1ms)

  print "→ resident + transient hints"
  dbus-notify test-hints "Resident transient hints" "Tests boolean hint parsing and capability tolerance." [] [resident b "true" transient b "true"] 7000
  sleep ($delay * 1ms)
  print "done — all notifications sent"
}
