#!/usr/bin/env zsh

_fzf_history() {
    local de_duplicated_history=("${(@f)$(fc -lnr 0 | awk '!seen[$0]++')}")
    local history_for_fzf=$(noglob printf '%s\000' "${de_duplicated_history[@]}")
    if [[ -z "$history_for_fzf" ]]; then
        zle send-break
        return 1
    fi
    local current_query="$BUFFER"
    local fzf_opts=(
        --read0
        --cycle
        --no-multi
        --padding=1,0,0,1
        --prompt="history > "
        --query="$current_query"
        --layout=reverse
    )
    local selected_command
    if ! (( $+commands[fzf] )); then
        print -u2 "Error: fzf command not found." >&2
        zle send-break
        return 1
    fi
    selected_command=$(fzf "${fzf_opts[@]}" <<< "$history_for_fzf")
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
    )
    local selection
    selection=$(fd -t f -t d -H --follow --color=never --exclude .git | fzf "${fzf_opts[@]}")
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

zle -N _fzf_history
bindkey '^R' _fzf_history

export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
--color=16,bg+:-1,fg+:4,pointer:4,marker:4 --preview-border='line'
--marker=: --bind=ctrl-y:toggle+down --info=right"

zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':completion:*' menu no
