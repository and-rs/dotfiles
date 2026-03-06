alias yz = yazi
alias nv = nvim
alias r = exec nu
alias nd = neovide
alias sw = stow -t $env.HOME
alias c = clear --keep-scrollback
alias l = ls -a
alias ld = eza -lha --no-permissions --no-user --no-time
alias lt = eza -lhaT --no-permissions --no-user --no-time --git-ignore
alias caffeine = systemd-inhibit --what=idle:sleep --why="no-sleep" sleep infinity
alias link-nvim = ln -s $"($env.HOME)/Vault/personal/nvim" $"($env.HOME)/.config"

# Load opam env vars to the path (of course it isn't eval)
def --env "opam eval" [] {
  opam env --shell=powershell
  | lines
  | where ($it | str starts-with '$env:')
  | parse "$env:{key} = '{value}'"
  | transpose -rd
  | update PATH {|r| $r.PATH | split row (char esep)}
  | load-env
}

# Fastfetch
alias ff = fastfetch --logo-color-1 cyan --file $"($env.DOTS)/utils/ascii/spider2.txt"
alias ffn = fastfetch --logo-color-1 red --file $"($env.DOTS)/utils/ascii/spider2.txt" --config neofetch

# Docker + VM Start
def win-start [] {
  let is_running = (
    docker inspect -f '{{.State.Running}}' WinBoat | complete | get stdout | str trim
  )
  if $is_running != "true" {
    docker start WinBoat
    sleep 10sec
  }
  xfreerdp /v:127.0.0.1:47300 /u:andrs /p:jersey +clipboard /cert:ignore -compression +dynamic-resolution /scale:180
}

# VSCode Darwin check
def code [...args] {
  if (sys host | get name) != "Darwin" { return 1 }
  with-env { VSCODE_CWD: (pwd) } {
        ^open -n -b "com.microsoft.VSCode" --args ...$args
    }
}
