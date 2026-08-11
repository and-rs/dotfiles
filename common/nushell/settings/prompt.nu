# Insert one visual gap after commands, except commands that clear the screen.
$env.PROMPT_GAP = (($env.PROMPT_GAP? | default false | into string) == "true")

$env.config.hooks.pre_execution = [
  {||
    $env.PROMPT_GAP = not ((commandline) =~ '^\s*(c|clear(\s+(-k|--keep-scrollback))?)\s*$')
  }
]

$env.config.hooks.pre_prompt = [
  {||
    if $env.PROMPT_GAP {
      print ""
      $env.PROMPT_GAP = false
    }
  }
]

export-env {
  $env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = null
  $env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = null

  $env.TRANSIENT_PROMPT_COMMAND = ""
  $env.TRANSIENT_PROMPT_INDICATOR = {|| $"(ansi grey)▶(ansi reset) " }
  $env.TRANSIENT_PROMPT_COMMAND_RIGHT = null

  $env.PROMPT_MULTILINE_INDICATOR = $"(ansi grey)▎ (ansi reset)"
  $env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = $"(ansi grey)▎ (ansi reset)"
}
