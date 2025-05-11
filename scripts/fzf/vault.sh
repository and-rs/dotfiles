#!/bin/bash

cd "$HOME/vault" || exit

directories=(fd --type d)

# Add more flags
directories+=(--hidden --exclude .git --exclude node_module --exclude .cache --exclude .npm --exclude .mozilla --exclude .meteor --exclude .nv)
directories+=(--exact-depth 2)

# Use the array to execute the fd command and pipe to fzf-tmux for fuzzy finding in a tmux pane
selected_dir=$("${directories[@]}" | fzf --tmux='center,40%' --border='sharp' --info='right' --prompt='')

if [ -n "$selected_dir" ]; then
    cd "$selected_dir" || exit
else
    echo "No directory selected."
fi

