_qsv_select_headers() {
    for cmd in fd fzf qsv awk paste; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            printf 'error: required command %s not found\n' "$cmd" >&2
            return 1
        fi
    done
    local -a fzf_opts=(
        --prompt="file > "
        --padding=1,0,0,1
        --layout=reverse
        --height=60%
        --no-multi
    )
    local -a fzf_opts_headers=(
        --prompt="headers > "
        --padding=1,0,0,1
        --layout=reverse
        --height=60%
        --multi
    )
    if [[ ${words[2]} != "select" ]]; then
        return 0
    fi
    local file
    file=$(fd -t f -e csv -e tsv -e ssv -e tab \
            -H --follow --color=never --exclude .git \
        | fzf "${fzf_opts[@]}") || return 1
    clear
    local headers
    headers=$(
        qsv headers "$file" \
            | fzf "${fzf_opts_headers[@]}" \
            | awk '{sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); print}' \
            | paste -sd ',' -
    ) || return 1
    if [[ -z $headers ]]; then
        return 1
    else
        compadd -Q -- "$(printf '%q' "$headers") $(printf '%q' "$file")"
    fi
}

compdef _qsv_select_headers qsv
