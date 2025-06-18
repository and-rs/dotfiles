#!/usr/bin/env zsh

fzf-history() {
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
    zle -R
}

zle -N fzf-history
bindkey '^R' fzf-history

export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS 
  --color=16,bg+:-1,fg+:4,pointer:4,marker:4 
  --marker=: --multi --bind=ctrl-y:toggle+down --info=right"

zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':completion:*' menu no
