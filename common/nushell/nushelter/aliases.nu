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

# Maintenance
alias clean-nix = do {
  sudo nix-collect-garbage -d
  nix-collect-garbage -d
  nix store optimise
}
alias update-darwin = sudo darwin-rebuild switch --flake $"($env.HOME)/Vault/personal/nixos#M1"
alias update-nixos = sudo nixos-rebuild switch --flake $"($env.HOME)/Vault/personal/nixos#default"
alias update-nixos-boot = sudo nixos-rebuild boot --flake $"($env.HOME)/Vault/personal/nixos#default"
alias link-nvim = ln -s $"($env.HOME)/Vault/personal/nvim" $"($env.HOME)/.config"

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
  ^nohup xfreerdp /v:127.0.0.1:47300 /u:andrs /p:jersey +clipboard /cert:ignore -compression +dynamic-resolution /scale:180 & out+err> /dev/null
}

# VSCode Darwin check
def code [...args] {
  if (sys host | get name) != "Darwin" { return 1 }
  with-env { VSCODE_CWD: (pwd) } {
        ^open -n -b "com.microsoft.VSCode" --args ...$args
    }
}
