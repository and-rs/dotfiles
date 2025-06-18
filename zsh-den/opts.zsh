#!/usr/bin/env zsh

export EDITOR='nvim'
export MANPAGER='nvim +Man!'

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
