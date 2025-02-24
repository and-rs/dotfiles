#!/bin/bash

directories=(fd --type f)

# Add more flags
directories+=(--hidden --exclude .git --exclude node_module --exclude .cache --exclude .npm --exclude .mozilla --exclude .meteor --exclude .nv)

# Use the array to execute the fd command and pipe to fzf-tmux for fuzzy finding in a tmux pane
selected_dir=$("${directories[@]}" | fzf --reverse --tmux='center,33%')

if [ -n "$selected_dir" ]; then
    nvim "$selected_dir" || exit
else
    nvim
fi
