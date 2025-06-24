#!/usr/bin/env zsh

DOTS="$HOME/vault/personal/dotfiles"

zd() {
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

ze() {
  local file
  file=$(fzf --prompt="edit > " --reverse --info="right" --padding=1,0,0,1)
  [[ -n $file ]] && $EDITOR "$file"
}

alias ..="z .."
alias nv="nvim"
alias c="clear -x"
alias reload="exec zsh"
alias sw="stow -t $HOME"

alias l="eza -liha"
alias lt="eza -lihaT --git-ignore"

# alias f=". $DOTS/scripts/fzf/search.sh"
# alias s=". $DOTS/scripts/fzf/vault.sh"

alias u-nixos="sudo nixos-rebuild switch --flake $HOME/vault/personal/nixos#default"
alias u-darwin="sudo darwin-rebuild switch --flake $HOME/vault/personal/nix-darwin"

alias ff="fastfetch --logo-color-1 red --file $DOTS/utils/ascii/spider2.txt"
alias ffn="fastfetch --logo-color-1 red --file $DOTS/utils/ascii/spider2.txt --config neofetch"
