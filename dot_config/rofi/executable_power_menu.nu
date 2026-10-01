#!/usr/bin/env -S nu --no-config-file

const SCRIPT_DIR = (path self | path dirname)
source ($SCRIPT_DIR | path join "rofi_icons.nu")

const CHOICES = [
  {id: shutdown label: "Shut down" icon: shutdown}
  {id: reboot label: "Reboot" icon: reboot}
  {id: suspend label: "Suspend" icon: suspend}
  {id: hibernate label: "Hibernate" icon: hibernate}
  {id: logout label: "Log out" icon: logout}
  {id: lockscreen label: "Lock screen" icon: lockscreen}
]

def emit-row [info: string, icon: string, label: string, no_symbols: bool, no_text: bool] {
  let row = (rofi-row $icon $label --no-icon=$no_symbols --no-text=$no_text)
  print -n ($row + (char nul) + "info" + (char --integer 31) + $info + (char newline))
}

def emit-menu-metadata [prompt: string] {
  print -n ((char nul) + "no-custom" + (char --integer 31) + "true" + (char newline))
  print -n ((char nul) + "markup-rows" + (char --integer 31) + "true" + (char newline))
  print -n ((char nul) + "prompt" + (char --integer 31) + $prompt + (char newline))
}

def validate-choices [name: string, values: list<string>] {
  let invalid = ($values | where {|value| ($CHOICES | all {|choice| $choice.id != $value})})
  if not ($invalid | is-empty) {
    error make {msg: $"Invalid choice in --($name): ($invalid | str join ', ')"}
  }
}

def execute-action [id: string, dry_run: bool] {
  if $dry_run {
    print -e $"Selected: ($id)"
    return
  }
  match $id {
    "lockscreen" => {
      let session = ($env.XDG_SESSION_ID? | default "")
      if $session == "" {
        ^loginctl lock-session
      } else {
        ^loginctl lock-session $session
      }
    }
    "logout" => {
      let session = ($env.XDG_SESSION_ID? | default "")
      if $session == "" {
        ^loginctl terminate-session
      } else {
        ^loginctl terminate-session $session
      }
    }
    "suspend" => { ^systemctl suspend }
    "hibernate" => { ^systemctl hibernate }
    "reboot" => { ^systemctl reboot }
    "shutdown" => { ^systemctl poweroff }
    _ => { error make {msg: $"unknown power action: ($id)"} }
  }
}

def main [
  --dry-run
  --choices: string = "shutdown/reboot/suspend/hibernate/logout/lockscreen"
  --confirm: string = "reboot/shutdown/logout"
  --choose: string
  --symbols = true
  --no-symbols
  --text = true
  --no-text
  ...selection: string
] {
  let choices = ($choices | split row "/")
  let confirmations = ($confirm | split row "/")
  validate-choices "choices" $choices
  validate-choices "confirm" $confirmations

  let show_symbols = (not $no_symbols) and $symbols
  let show_text = (not $no_text) and $text
  if not $show_symbols and not $show_text {
    error make {msg: "Cannot disable both symbols and text."}
  }

  let info = ($env.ROFI_INFO? | default "")
  let selected = if $info != "" {
    $info
  } else if $choose != null {
    $"power:($choose)"
  } else {
    $selection | str join " "
  }

  if $selected == "" {
    emit-menu-metadata "Power"
    for id in $choices {
      let choice = ($CHOICES | where id == $id | first)
      emit-row $"power:($id)" $choice.icon $choice.label (not $show_symbols) (not $show_text)
    }
    return
  }

  if $selected == "confirm:cancel" {
    return
  }

  if ($selected | str starts-with "confirm:") {
    let confirmed_id = ($selected | str replace "confirm:" "")
    if not ($choices | any {|id| $id == $confirmed_id}) {
      error make {msg: $"Invalid confirmation selection: ($confirmed_id)"}
    }
    execute-action $confirmed_id $dry_run
    return
  }

  let id = if ($selected | str starts-with "power:") {
    $selected | str replace "power:" ""
  } else {
    $selected
  }
  let choice = ($CHOICES | where id == $id | first)
  if $choice == null or not ($choices | any {|candidate| $candidate == $id}) {
    error make {msg: $"Invalid selection: ($selected)"}
  }

  if ($confirmations | any {|confirmation| $confirmation == $id}) {
    emit-menu-metadata "Are you sure"
    emit-row $"confirm:($id)" $choice.icon $"Yes, ($choice.label)" (not $show_symbols) (not $show_text)
    emit-row "confirm:cancel" "cancel" "No, cancel" (not $show_symbols) (not $show_text)
    return
  }

  execute-action $id $dry_run
}
