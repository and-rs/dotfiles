#!/usr/bin/env zsh

DOTS="$HOME/vault/personal/dotfiles"

alias ..="z .."
alias nv="nvim"
alias c="clear -x"
alias reload="exec zsh"
alias sw="stow -t $HOME"

alias l="eza -a"
alias ls="eza -liha"
alias lt="eza -lihaT --git-ignore"

alias f=". $DOTS/scripts/fzf/search.sh"
# alias s=". $DOTS/scripts/fzf/vault.sh"

alias u-nixos="sudo nixos-rebuild switch --flake $HOME/vault/personal/nixos#default"
alias u-darwin="sudo darwin-rebuild switch --flake $HOME/vault/personal/nix-darwin"

alias ff="fastfetch --logo-color-1 red --file $DOTS/utils/ascii/spider2.txt"
alias ffn="fastfetch --logo-color-1 red --file $DOTS/utils/ascii/spider2.txt --config neofetch"

code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;}

dirtree() {
  if ! command -v eza &> /dev/null; then
      echo "Error: 'eza' command not found. Please install eza to use this script."
      exit 1
  fi
  CLIPBOARD_CMD=""
  if command -v pbcopy &> /dev/null; then
      CLIPBOARD_CMD="pbcopy"
  elif command -v wl-copy &> /dev/null; then
      CLIPBOARD_CMD="wl-copy"
  else
      echo "Error: No clipboard utility found. Please install 'pbcopy' (macOS) or 'xclip' (Linux)."
      exit 1
  fi
  TREE_OUTPUT=$(eza -Ta --git-ignore)
  FORMATTED_OUTPUT="\`\`\`\n${TREE_OUTPUT}\n\`\`\`"
  echo -e "${FORMATTED_OUTPUT}" | ${CLIPBOARD_CMD}
  echo "eza tree output with markdown code blocks copied to clipboard!"
}

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
