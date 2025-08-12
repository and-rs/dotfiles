# Paste this oneliner on the default config file if necessary
# source "~/.config/nushell/config.nu"
source ./prompt.nu

$env.path ++= [
  $"($.env.HOME)/.nix-profile/bin"
  "/run/current-system/sw/bin"
]

$env.path = ($env.path | uniq)
$env.config.buffer_editor = "nvim"
$env.config.history.max_size = 1_000_000
$env.config.show_banner = false
$env.config.table.mode = "rounded"

let dots = $"($env.HOME)/vault/personal/dotfiles/"
let personal = $"($env.HOME)/vault/personal/"

if ("~/.zoxide.nu" | path exists) != true {
  zoxide init nushell | save -f ~/.zoxide.nu
}

source ~/.zoxide.nu

alias l = ls -a
alias nv = nvim
alias reload = exec nu
alias c = clear --keep-scrollback
alias ff = fastfetch --logo-color-1 red --file $"($dots)utils/ascii/spider2.txt"

def tablez [] {
  table --theme light | fzf --ansi --no-sort
}


$env.config = {
  hooks: {
    pre_prompt: [{ ||
      if (which direnv | is-empty) {
        return
      }

      direnv export json | from json | default {} | load-env
      if 'ENV_CONVERSIONS' in $env and 'PATH' in $env.ENV_CONVERSIONS {
        $env.PATH = do $env.ENV_CONVERSIONS.PATH.from_string $env.PATH
      }
    }]
  }
}
