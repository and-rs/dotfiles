oh-my-posh init nu --config ~/.config/oh-my-posh/config.yaml
# this is being ignored by oh-my-posh
$env.PROMPT_MULTILINE_INDICATOR = {|| $"(ansi grey)   & (ansi reset)" }
$env.TRANSIENT_PROMPT_COMMAND_RIGHT = null
$env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = null
$env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = null
$env.TRANSIENT_PROMPT_COMMAND = {|| $"\n(ansi grey)── " }
$env.TRANSIENT_PROMPT_INDICATOR = {|| $"(ansi blue)$(ansi reset) " }
$env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = {|| $"(ansi grey)   & (ansi reset)" }
