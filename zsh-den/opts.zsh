#!/usr/bin/env zsh

export EDITOR='nvim'
export MANPAGER='nvim +Man!'
export BAT_THEME='tokyonight-nosyntax'

# History options
HISTSIZE=7000
SAVEHIST=$HISTSIZE
HISTDUP=erase

setopt hist_ignore_all_dups
setopt hist_find_no_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt appendhistory
setopt sharehistory

setopt glob_dots
setopt no_auto_menu
setopt no_list_beep

bindkey -e

bindkey '^K' kill-line
bindkey '^U' backward-kill-line

bindkey '^D' delete-char
bindkey '^F' forward-char
bindkey '^B' backward-char

bindkey '^P' up-line-or-history
bindkey '^N' down-line-or-history

bindkey '^E' end-of-line
bindkey '^A' beginning-of-line

zstyle ':completion:*' insert-tab false
