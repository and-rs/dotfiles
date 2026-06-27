#!/usr/bin/env nu

# Fires a batch of test notifications to exercise the notification stack.
# Usage: nu test-notifs.nu [--delay <ms>]

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

def main [--delay: int = 300] {
  let img = ($env.FILE_PWD | path join "../wallpapers/stars.png" | path expand)

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
      label: "long body (tests 5-line wrap)"
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
      icon: $img
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
  dbus-notify test-image-hint "Image hint" "Image comes from image-path hint, not icon." [] [image-path s $img] 7000
  sleep ($delay * 1ms)

  print "→ resident + transient hints"
  dbus-notify test-hints "Resident transient hints" "Tests boolean hint parsing and capability tolerance." [] [resident b "true" transient b "true"] 7000
  sleep ($delay * 1ms)
  print "done — all notifications sent"
}
