use std/config *

# Nix path
$env.path ++= [
  $"($env.HOME)/.nix-profile/bin"
  "/run/current-system/sw/bin"
]

# MUST be at the top: custom oh-my-posh setup
source nushelter/prompt.nu

if $nu.is-interactive and (($env.TMUX? | default "" | is-empty)) and ((which tmux | is-empty) == false) {
  exec tmux -u new -s code -A -D
}

# Generate zoxide
if ("~/.config/nushell/zoxide.nu" | path exists) != true {
  zoxide init nushell | save -f ~/.config/nushell/zoxide.nu
}

# Env vars
$env.path = ($env.path | uniq)
$env.config.buffer_editor = "nvim"
$env.config.history = {
  max_size: 100_000
  sync_on_enter: true
  file_format: "sqlite"
  isolation: false
}
$env.config.show_banner = false
$env.config.table.mode = "rounded"

# Options
$env.EDITOR = "nvim"
$env.MANPAGER = "nvim +Man!"
$env.BAT_THEME = "nosyntax"
$env.DIRENV_LOG_FORMAT = "" # Silence direnv logs
$env.AICHAT_CONFIG_DIR = $"($env.HOME)/.config/aichat"
$env.DOTS = $"($env.HOME)/Vault/personal/dotfiles/"

$env.FZF_DEFAULT_OPTS = (
  "--color=16,bg:-1,bg+:-1,fg:8,fg+:4,pointer:4,marker:4,gutter:0,header:5,border:0,hl:6,hl+:6,info:6 " +
  "--preview-border=line " +
  "--marker=':' --gutter=' ' --pointer='>' " +
  "--bind=ctrl-y:toggle+down --info=right"
)
$env._ZO_FZF_OPTS = ($env.FZF_DEFAULT_OPTS +
  " --padding=1,0,0,1 --prompt='zoxide interactive > ' " +
  " --layout=reverse --height=100% --multi --cycle"
)

# Nushelter
source nushelter/theme.nu
source nushelter/clip.nu
source nushelter/keybinds.nu
source nushelter/aliases.nu
source nushelter/aichat.nu
source nushelter/rclone.nu
source nushelter/utils.nu
source nushelter/data.nu
source nushelter/grit.nu
source nushelter/git.nu

# Completions
source completions/git_completions.nu

# Util source
$env.config.hooks.env_change.PWD = $env.config.hooks.env_change.PWD? | default []
$env.config.hooks.env_change.PWD ++= [
  {||
    if (which direnv | is-empty) { return }
    direnv export json | from json | default {} | load-env
    $env.PATH = do (env-conversions).path.from_string $env.PATH
  }
]

# Zoxide
source zoxide.nu
alias cd = z
alias ci = zi
