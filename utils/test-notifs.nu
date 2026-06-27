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

  print "done — all notifications sent"
}
