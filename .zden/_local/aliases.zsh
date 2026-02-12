#!/usr/bin/env zsh

alias cd="z"
alias ci="zi"
alias ..="z .."
alias yz="yazi"
alias nv="nvim"
alias nd="neovide"
alias c="clear -x"
alias reload="exec zsh"
alias sw="stow -t $HOME"
alias caffeine="systemd-inhibit --what=idle:sleep --why="no-sleep" sleep infinity"

# current AI setup?
alias ai="aichat -r meaningful -s"
alias aie="aichat -e"

alias l="eza -lha --no-time --no-permissions --no-user -I .DS_Store"
alias ld="eza -lha --no-filesize --no-permissions --no-user -I .DS_Store"
alias lt="eza -lihaT --git-ignore"
alias ls="eza -liha"

alias link-nvim="ln -s $HOME/Vault/personal/nvim $HOME/.config"
alias clean-nix="sudo nix-collect-garbage -d && nix-collect-garbage -d && nix store optimise"
alias update-darwin="sudo darwin-rebuild switch --flake $HOME/Vault/personal/nixos#M1"
alias update-nixos="sudo nixos-rebuild switch --flake $HOME/Vault/personal/nixos#default"
alias update-nixos-boot="sudo nixos-rebuild boot --flake $HOME/Vault/personal/nixos#default"

alias ff="fastfetch --logo-color-1 cyan --file $DOTS/utils/ascii/spider2.txt"
alias ffn="fastfetch --logo-color-1 red --file $DOTS/utils/ascii/spider2.txt --config neofetch"

win-start() {
    if [ "$(docker inspect -f '{{.State.Running}}' WinBoat 2>/dev/null)" != "true" ]; then
        docker start WinBoat
        sleep 10
    fi
    nohup xfreerdp /v:127.0.0.1:47300 /u:andrs /p:jersey \
        +clipboard /cert:ignore -compression \
        +dynamic-resolution /scale:180 >/dev/null 2>&1 &
}

code() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        return 1
    fi
    VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args "$@"
}

f() {
    directories=(fd --type d)
    directories+=(
        --hidden
        --exclude node_module
        --exclude .git
        --exclude .cache
        --exclude .npm
        --exclude .mozilla
        --exclude .meteor
        --exclude .nv
    )
    selected_dir=$("${directories[@]}" | fzf --prompt="choose directory > " --reverse --info="right" --padding=1,0,0,1)
    if [ -n "$selected_dir" ]; then
        cd "$selected_dir" || exit
    else
        echo "No directory selected."
    fi
}

fe() {
    local file
    file=$(fd --exclude .git --hidden | fzf --prompt="edit > " --reverse --info="right" --padding=1,0,0,1)
    [[ -n $file ]] && $EDITOR "$file"
}
