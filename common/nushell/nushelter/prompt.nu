^oh-my-posh init nu --config ~/.config/oh-my-posh/config.yaml --print | save --force ~/.cache/oh-my-posh-init.nu
source ~/.cache/oh-my-posh-init.nu

$env.TRANSIENT_PROMPT_COMMAND_RIGHT = null
$env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = null
$env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = null
$env.TRANSIENT_PROMPT_COMMAND = {|| $"\n(ansi grey)── " }
$env.TRANSIENT_PROMPT_INDICATOR = {|| $"(ansi blue)$(ansi reset) " }
$env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = {|| $"(ansi grey)   & (ansi reset)" }
$env.PROMPT_MULTILINE_INDICATOR = {|| $"(ansi grey)   (ansi blue)& (ansi reset)" }
