use std/config *

# Paths & nix path: keep at top!
$env.PATH ++= [
  "/run/current-system/sw/bin"
  $"($env.HOME)/.bun/bin"
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
  exec tmux -u new -s work -A -D
}

# Options
export-env {
  $env.path = ($env.path | uniq)
  $env.config.history = {
    isolation: false
    max_size: 100_000
    sync_on_enter: true
    file_format: "sqlite"
  }
  $env.config.show_banner = false
  $env.config.table.mode = "markdown"
  $env.config.completions.quick = false
  $env.config.completions.partial = false

  $env.XDG_CONFIG_HOME = $"($env.HOME)/.config"
  $env.TOPIARY_CONFIG_FILE = ($env.XDG_CONFIG_HOME | path join topiary languages.ncl)
  $env.TOPIARY_LANGUAGE_DIR = ($env.XDG_CONFIG_HOME | path join topiary queries)

  let node_extra_ca = "/usr/local/share/ca-certificates/ocpamacaroot1.crt"
  if ($node_extra_ca | path exists) {
    $env.NODE_EXTRA_CA_CERTS = $node_extra_ca
  }

  let bob_version = "0.12.2"
  if not (which bob | is-empty) {
    let bob_cmd = ["bob" "run" $bob_version]
    let bob_run = $"((which bob | get path | first)) run ($bob_version)"
    $env.config.buffer_editor = $bob_cmd
    $env.EDITOR = $bob_run
    $env.VISUAL = $bob_run
    $env.SUDO_EDITOR = $bob_run
    $env.MANPAGER = $"($bob_run) +Man!"
  } else if not (which nvim | is-empty) {
    $env.config.buffer_editor = "nvim"
    $env.EDITOR = "nvim"
    $env.VISUAL = "nvim"
    $env.SUDO_EDITOR = "nvim"
    $env.MANPAGER = "nvim +Man!"
  } else {
    $env.config.buffer_editor = "vim"
    $env.EDITOR = "vim"
    $env.VISUAL = "vim"
    $env.SUDO_EDITOR = "vim"
    $env.MANPAGER = "vim +Man!"
  }

  $env.LS_COLORS = "di=34:ln=36:ex=32:fi=0:pi=33:so=35:bd=33;01:cd=33;01:or=31;01:mi=31:*.tar=31:*.gz=31:*.zip=31:*.bz2=31:*.xz=31:*.7z=31:*.rar=31:*.zst=31:*.jpg=35:*.jpeg=35:*.png=35:*.gif=35:*.svg=35:*.mp4=35:*.mkv=35:*.mov=35:*.mp3=33:*.flac=33:*.wav=33"
  $env.BAT_THEME = "tokyonight-day-nosyntax"
  $env.DOTS = $"($env.HOME)/Vault/personal/dotfiles/"
  $env.FZF_DEFAULT_OPTS = [
    "--bind=ctrl-y:toggle+down --info=right --reverse"
    "--color=16,bg:-1,bg+:0,fg:8,fg+:4,pointer:4,marker:4,gutter:0,header:5,border:0,hl:6,hl+:6,info:6"
    "--preview-border=line"
    "--pointer='>'"
    "--marker=':'"
    "--gutter=' '"
  ] | str join " "

  $env._ZO_FZF_OPTS = [
    $env.FZF_DEFAULT_OPTS
    "--padding=1,0,0,1"
    "--prompt='Zoxide Interactive > '"
    "--layout=reverse --height=100% --multi --cycle"
  ] | str join " "
  $env.config.hooks.env_change.PWD = $env.config.hooks.env_change.PWD? | default []
  $env.config.hooks.env_change.PWD ++= [
    {||
      if (which direnv | is-empty) { return }
      direnv export json | from json | default {} | load-env
      $env.PATH = do (env-conversions).path.from_string $env.PATH
    }
  ]
}

source nushelter/clip.nu # 1st
source nushelter/aliases.nu
source nushelter/spinner.nu
source nushelter/screen.nu
source nushelter/ret.nu
source nushelter/utils.nu
source nushelter/data.nu
source nushelter/grit.nu
source nushelter/git.nu
source completions/just_completions.nu

# Pi setup 8ms
use pi *

# Forgit & git completions 8ms
use forgit *

# Generate zoxide
if ($"($env.HOME)/.config/nushell/zoxide.nu" | path exists) != true {
  zoxide init nushell | save -f ~/.config/nushell/zoxide.nu
}
source zoxide.nu
alias "cd" = z
alias "ci" = zi

# Generate carapace
let autoload_dir = $nu.vendor-autoload-dirs | last
if not ($autoload_dir | path exists) {
  mkdir $autoload_dir
}
carapace _carapace nushell | save -f $"($autoload_dir)/carapace.nu"

# only enable when debugging
# export-env {
#   $env.is_startup = false
#   $env.config.hooks.pre_prompt = [
#     {||
#       if $nu.is-interactive and not $env.is_startup {
#         print $"\n(ansi cyan)took > (ansi rst)($nu.startup-time)\n"
#         $env.is_startup = true
#       }
#     }
#   ]
# }
