#!/usr/bin/env zsh

_fzf_history() {
    local current_query="$BUFFER"
    local fzf_opts=(
        --read0
        --cycle
        --no-multi
        --padding=1,0,0,1
        --prompt="history > "
        --query="$current_query"
        --layout=reverse
        --tiebreak=index
    )
    if (( ! $+commands[fzf] )); then
        print -u2 "Error: fzf command not found."
        zle send-break
        return 1
    fi
    local selected_command
    selected_command=$(fc -lnr 0 | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if (!seen[$0]++) print}' | tr '\n' '\0' | fzf "${fzf_opts[@]}")
    if [[ $? -eq 0 && -n "$selected_command" ]]; then
        BUFFER="$selected_command"
        CURSOR=${#BUFFER}
    fi
    zle redisplay
}

_fzf_insert_path_widget() {
    local fzf_opts=(
        --padding=1,0,0,1
        --prompt="path > "
        --layout=reverse
        --height=60%
        --multi
        --cycle
    )
    local selection
    selection=$(fd -t f -t d -H --follow --color=never -E .git -E .DS_Store --maxdepth 1 | fzf "${fzf_opts[@]}")
    if [[ -n "$selection" ]]; then
        local quoted_selections=()
        while IFS= read -r line; do
            quoted_selections+=("$(printf "%q" "$line")")
        done <<< "$selection"
        LBUFFER+="${quoted_selections[*]}"
    fi
    zle redisplay
    command -v _zsh_autosuggest_clear >/dev/null 2>&1 && _zsh_autosuggest_clear
}

_fzf_insert_path_widget_recursive() {
    local fzf_opts=(
        --padding=1,0,0,1
        --prompt="path (recursive) > "
        --layout=reverse
        --height=60%
        --multi
        --cycle
    )
    local selection
    selection=$(fd -t f -t d -H --follow --color=never -E .git -E .DS_Store | fzf "${fzf_opts[@]}")
    if [[ -n "$selection" ]]; then
        local quoted_selections=()
        while IFS= read -r line; do
            quoted_selections+=("$(printf "%q" "$line")")
        done <<< "$selection"
        LBUFFER+="${quoted_selections[*]}"
    fi
    zle redisplay
    command -v _zsh_autosuggest_clear >/dev/null 2>&1 && _zsh_autosuggest_clear
}

zle -N _fzf_insert_path_widget
bindkey '^T' _fzf_insert_path_widget

zle -N _fzf_insert_path_widget_recursive
bindkey '^G' _fzf_insert_path_widget_recursive

zle -N _fzf_history
bindkey '^R' _fzf_history

export FORGIT_GLO_FORMAT="%C(auto)%h%d %C(green)%s%C(reset)"

export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} \
  --color=16,bg:-1,bg+:-1,fg:8,fg+:4,pointer:4,marker:4,gutter:0,header:5,border:0,hl:6,hl+:6,info:6 \
  --preview-border=line \
  --marker=':' --gutter=' ' --pointer='>' \
  --bind=ctrl-y:toggle+down --info=right"

export _ZO_FZF_OPTS="${FZF_DEFAULT_OPTS:-} \
  --color=16,bg:-1,bg+:-1,fg:8,fg+:4,pointer:4,marker:4,gutter:0,header:5,border:0,hl:6,hl+:6,info:6 \
  --preview-border=line \
  --marker=':' --gutter=' ' --pointer='>' \
  --bind=ctrl-y:toggle+down --info=right \
  --padding=1,0,0,1 --prompt='zoxide interactive > ' \
  --layout=reverse --height=100% --multi --cycle"

zstyle ':completion:*' menu no
zstyle ':fzf-tab:*' use-fzf-default-opts yes
