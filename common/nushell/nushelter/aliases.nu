alias nv = ^$env.EDITOR
alias link-nvim = ln -s ~/Vault/personal/nvim ~/.config
alias yz = yazi
alias l = ls -a
alias r = exec nu
alias md = table -t markdown
alias c = clear --keep-scrollback
alias ld = eza -lha --no-permissions --no-user --no-time
alias lt = eza -lhaT --no-permissions --no-user --no-time --git-ignore
alias caffeine = systemd-inhibit --what=idle:sleep --why="no-sleep" sleep infinity
alias ff = fastfetch --logo-color-1 cyan --file $"($env.DOTS)/utils/ascii/spider2.txt"
alias ffn = fastfetch --logo-color-1 red --file $"($env.DOTS)/utils/ascii/spider2.txt" --config neofetch

# Load opam env vars to the path (of course it isn't eval) (with oxcaml handling)
def --env "opam eval" [switch?: string] {
  if ($switch | is-empty) { $env.OPAMSWITCH = "5.2.0+ox" }
  opam env --shell=powershell (if ($switch | is-empty) { "--switch=5.2.0+ox" })
  | lines
  | where ($it | str starts-with '$env:')
  | parse "$env:{key} = '{value}'"
  | transpose -rd
  | update PATH {|r| $r.PATH | split row (char esep) }
  | load-env
}

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
  with-env {VSCODE_CWD: (pwd)} {
    ^open -n -b "com.microsoft.VSCode" --args ...$args
  }
}
