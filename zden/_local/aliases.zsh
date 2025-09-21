#!/usr/bin/env zsh

DOTS="$HOME/vault/personal/dotfiles"

alias yz="yazi"
alias nv="nvim"
alias ..="z .."
alias c="clear -x"
alias reload="exec zsh"
alias sw="stow -t $HOME"

alias l="eza -lha --no-time --no-permissions --no-user -I .DS_Store"
alias ld="eza -lha --no-filesize --no-permissions --no-user -I .DS_Store"
alias lt="eza -lihaT --git-ignore"
alias ls="eza -liha"

alias update-nixos="sudo nixos-rebuild switch --flake $HOME/vault/personal/nixos#default"
alias update-darwin="sudo darwin-rebuild switch --flake $HOME/vault/personal/nix-darwin"

alias ff="fastfetch --logo-color-1 cyan --file $DOTS/utils/ascii/spider2.txt"
alias ffn="fastfetch --logo-color-1 red --file $DOTS/utils/ascii/spider2.txt --config neofetch"

code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;}

f() {
    directories=(fd --type d)
    directories+=(
        --hidden
        --exclude .git
        --exclude node_module
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

fp() {
    local current_dir
    current_dir=$(pwd)
    cd "$HOME/vault" || return 1
    local dir
    dir=$(fd -t d --exact-depth 2 | fzf --prompt="projects > " --reverse --info="right" --padding=1,0,0,1)
    if [[ -n $dir ]]; then
        cd "$dir"
    else
        cd "$current_dir"
    fi
}

fe() {
    local file
    file=$(fd --exclude .git --hidden | fzf --prompt="edit > " --reverse --info="right" --padding=1,0,0,1)
    [[ -n $file ]] && $EDITOR "$file"
}
