def _has-cmd [cmd: string] {
  (which $cmd | is-empty) == false
}

def _require-cmd [cmd: string] {
  if not (_has-cmd $cmd) {
    error make {msg: $"Missing command: ($cmd)"}
  }
}

def _is-integrated [name: string] {
  ($name | str starts-with "eDP") or ($name | str starts-with "LVDS") or ($name | str starts-with "DSI")
}

def _niri-outputs [] {
  _require-cmd "niri"
  let out = (niri msg --json outputs | complete)
  if $out.exit_code != 0 {
    error make {msg: $"niri msg outputs failed: ($out.stderr | str trim)"}
  }
  let parsed = (try { $out.stdout | from json } catch { [] })
  if (($parsed | describe | str starts-with "record")) {
    let cols = ($parsed | columns)
    if ($cols | any {|c| $c == "outputs" }) {
      $parsed.outputs? | default []
    } else {
      $parsed | values
    }
  } else {
    $parsed
  }
}

def _outputs [] {
  let base = (_niri-outputs)
  let list = if (($base | describe | str starts-with "record")) { [$base] } else { $base }

  let mapped = (
    $list
    | each {|o|
      let name = ($o.name? | default "")
      let kind = (if (_is-integrated $name) { "integrated" } else { "external" })
      {
        name: $name
        kind: $kind
        enabled: ($o.enabled? | default true)
        scale: (($o.logical?.scale?) | default ($o.scale? | default null))
        make: ($o.make? | default "")
        model: ($o.model? | default "")
      }
    }
  )

  if (($mapped | describe | str starts-with "record")) {
    if (($mapped.name? | default "") == "") { [] } else { [$mapped] }
  } else {
    $mapped | where name != ""
  }
}

def _pick-output [prompt: string] {
  _require-cmd "fzf"
  let outs = (_outputs)
  if ($outs | is-empty) {
    return null
  }
  let rows = (
    $outs
    | each {|o|
      let status = (if $o.enabled { "on" } else { "off" })
      let scale_text = ($o.scale | default "-" | into string)
      let label = ([$o.make $o.model] | where $it != "" | str join " ")
      $"($o.name)	($o.kind)	($status)	($scale_text)	($label)"
    }
  )
  let picked = (
    $rows
    | str join (char nl)
    | ^fzf --prompt $prompt --height 40% --layout reverse
    | str trim
  )
  if ($picked | is-empty) {
    return null
  }
  $picked | split row (char tab) | first
}

def _display-solo [target: string] {
  let outs = (_outputs)
  let exists = ($outs | where name == $target)
  if ($exists | is-empty) {
    error make {msg: $"Unknown output: ($target)"}
  }
  for o in $outs {
    if $o.name == $target {
      niri msg output $o.name on
    } else {
      niri msg output $o.name off
    }
  }
}
def _display-state-path [] {
  let cache = ($env.XDG_CACHE_HOME? | default ($"($env.HOME)/.cache"))
  $cache | path join "nushell" "display-state.json"
}

def _save-display-state [] {
  let enabled = (_outputs | where enabled == true | each {|o| $o.name })
  if ($enabled | is-empty) {
    return
  }
  let path = (_display-state-path)
  mkdir ($path | path dirname)
  { enabled: $enabled } | to json | save -f $path
}

def _load-display-state [] {
  let path = (_display-state-path)
  if not ($path | path exists) {
    return []
  }
  try {
    open $path | get enabled? | default []
  } catch {
    []
  }
}

def _apply-display-state [enabled_names] {
  let outs = (_outputs)
  if ($outs | is-empty) {
    return
  }
  for o in $outs {
    if ($enabled_names | any {|name| $name == $o.name }) {
      niri msg output $o.name on
    } else {
      niri msg output $o.name off
    }
  }
}

def _restore-display-state [] {
  let saved = (_load-display-state)
  if ($saved | is-empty) {
    return false
  }
  _apply-display-state $saved
  true
}

def display [--help (-h)] {
  if not $help {
    print "Usage: display <subcommand>"
    print "  display list"
    print "  display scale"
    print "  display solo"
    print "  display back"
    print "  display external"
    print "  display auto"
    print "  display profile <auto|laptop|integrated|external|solo>"
    return
  }
  display
}

def "display list" [] {
  _outputs | select name kind enabled scale make model
}

def "display scale" [] {
  let target = (_pick-output "Scale display > ")
  if ($target | is-empty) {
    return
  }
  let input_scale = (input "Scale (0.5-4.0) > " | str trim)
  if ($input_scale | is-empty) {
    return
  }
  let scale = (try { $input_scale | into float } catch { null })
  if ($scale == null) or ($scale < 0.5) or ($scale > 4.0) {
    error make {msg: "Scale must be a number between 0.5 and 4.0"}
  }
  niri msg output $target scale ($scale | into string)
}

def --env "display solo" [] {
  let target = (_pick-output "Use only display > ")
  if ($target | is-empty) {
    return
  }
  _save-display-state
  _display-solo $target
  $env.DISPLAY_LAST_SOLO = $target
}

def "display back" [] {
  let restored = (_restore-display-state)
  if $restored {
    return
  }
  let outs = (_outputs)
  if ($outs | is-empty) {
    return
  }
  let integrated = ($outs | where kind == "integrated")
  if ($integrated | is-empty) {
    _display-solo ($outs | first | get name)
    return
  }
  for o in $outs {
    if $o.kind == "integrated" {
      niri msg output $o.name on
    } else {
      niri msg output $o.name off
    }
  }
}

def "display external" [] {
  let outs = (_outputs)
  let external = ($outs | where kind == "external")
  if ($external | is-empty) {
    print "No external display detected. Staying on integrated display."
    display back
    return
  }
  let active_external = ($external | where enabled == true)
  let target = (
    if ($active_external | is-empty) {
      $external | first | get name
    } else {
      $active_external | first | get name
    }
  )
  _save-display-state
  _display-solo $target
}

def "display auto" [] {
  let external = (_outputs | where kind == "external")
  if ($external | is-empty) {
    display back
  } else {
    display external
  }
}

def "display profile" [profile: string = "auto"] {
  match $profile {
    "laptop" => { display back }
    "integrated" => { display back }
    "external" => { display external }
    "solo" => { display solo }
    "auto" => { display auto }
    _ => { error make {msg: "Use one of: auto, laptop, integrated, external, solo"} }
  }
}
