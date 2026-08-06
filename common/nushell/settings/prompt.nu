let omp_init = ($nu.vendor-autoload-dirs | last | path join "oh-my-posh.nu")
let omp_path = (which oh-my-posh | get path.0 | path expand)
let omp_config = ("~/.config/oh-my-posh/config.yaml" | path expand --no-symlink)
let omp_current = if ($omp_init | path exists) {
  let init = (open --raw $omp_init)
  ($init | str contains $omp_path) and ($init | str contains $omp_config)
} else { false }
if not $omp_current {
  oh-my-posh init nu --config ~/.config/oh-my-posh/config.yaml
}

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
