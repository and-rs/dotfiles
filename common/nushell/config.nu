use std/config *

# Paths & nix path: keep at top!
$env.PATH ++= [
  "/run/current-system/sw/bin"
  $"($env.HOME)/bins"
  $"($env.HOME)/.local/bin"
  $"($env.HOME)/.nix-profile/bin"
  $"($env.HOME)/.config/nushell/execs"
  $"($env.HOME)/.config/nushell/forgit/helpers"
]

# custom oh-my-posh setup & misc
source settings/prompt.nu
source settings/theme.nu
source settings/keybinds.nu

if $nu.is-interactive and (($env.TMUX? | default "" | is-empty)) and ((which tmux | is-empty) == false) {
  exec tmux -u new -s code -A -D
}

# Options
export-env {
  $env.path = ($env.path | uniq)
  $env.config.buffer_editor = "nvim"
  $env.config.history = {
    isolation: false
    max_size: 100_000
    sync_on_enter: true
    file_format: "sqlite"
  }
  $env.config.show_banner = false
  $env.config.table.mode = "rounded"
  $env.config.completions.quick = false
  $env.config.completions.partial = false
  $env.XDG_CONFIG_HOME = $"($env.HOME)/.config"
  $env.TOPIARY_CONFIG_FILE = ($env.XDG_CONFIG_HOME | path join topiary languages.ncl)
  $env.TOPIARY_LANGUAGE_DIR = ($env.XDG_CONFIG_HOME | path join topiary queries)

  $env.EDITOR = $env.HOME + "/.local/share/bob/v0.12.0/bin/nvim"
  $env.MANPAGER = $env.EDITOR + " +Man!"

  $env.BAT_THEME = "nosyntax"
  $env.AICHAT_CONFIG_DIR = $"($env.HOME)/.config/aichat"
  $env.DOTS = $"($env.HOME)/Vault/personal/dotfiles/"
  $env.SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt"
  $env.NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt"
  $env.FZF_DEFAULT_OPTS = (
    "--color=16,bg:-1,bg+:-1,fg:8,fg+:4,pointer:4,marker:4,gutter:0,header:5,border:0,hl:6,hl+:6,info:6 " + "--preview-border=line " + "--marker=':' --gutter=' ' --pointer='>' " + "--bind=ctrl-y:toggle+down --info=right --reverse"
  )
  $env._ZO_FZF_OPTS = (
    $env.FZF_DEFAULT_OPTS + " --padding=1,0,0,1 --prompt='zoxide interactive > ' " + " --layout=reverse --height=100% --multi --cycle"
  )
}

source nushelter/clip.nu # 1st
source nushelter/aliases.nu
source nushelter/aichat.nu
source nushelter/utils.nu
source nushelter/data.nu
source nushelter/grit.nu
source nushelter/git.nu
source completions/just_completions.nu

# Forgit & git completions 8ms
use forgit *

export-env {
  $env.config.hooks.env_change.PWD = $env.config.hooks.env_change.PWD? | default []
  $env.config.hooks.env_change.PWD ++= [
    {||
      if (which direnv | is-empty) { return }
      direnv export json | from json | default {} | load-env
      $env.PATH = do (env-conversions).path.from_string $env.PATH
    }
  ]
}

# Generate zoxide
if ("~/.config/nushell/zoxide.nu" | path exists) != true {
  zoxide init nushell | save -f ~/.config/nushell/zoxide.nu
}
source zoxide.nu
alias "cd" = z
alias "ci" = zi

let autoload_dir = $nu.vendor-autoload-dirs | last
if not ($autoload_dir | path exists) {
  mkdir $autoload_dir
}
carapace _carapace nushell | save -f $"($autoload_dir)/carapace.nu"

# only enable when debugging
export-env {
  $env.is_startup = false
  $env.config.hooks.pre_prompt = [
    {||
      if $nu.is-interactive and not $env.is_startup {
        print $"\n(ansi cyan)took > (ansi rst)($nu.startup-time)\n"
        $env.is_startup = true
      }
    }
  ]
}
