alias ai="aichat -r meaningful -s"
alias aie="aichat -e"
alias ai:gc="aichat -r meaningful --macro commit"
alias ai:rag="aichat -r indexer --rag"

aie-extend-command() {
    local current=$BUFFER
    BUFFER="aichat -e \"${current//\"/\\\"} -- extend by: \""
    CURSOR=$(($#BUFFER - 1))
}

zle -N aie-extend-command
bindkey '\ee' aie-extend-command

ret() {
    local current_path=$(pwd)
    local base_cmd="yek \"$current_path\" --json | jq '[.[] | { path: .filename, contents: .content }]'"
    local opt_c=0
    local opt_p=0
    local OPTIND

    while getopts "cp" opt; do
        case "$opt" in
            c) opt_c=1 ;;
            p) opt_p=1 ;;
            *) return 1 ;;
        esac
    done

    if (( opt_p )); then
        eval "$base_cmd | rg \"\\\"path\\\"\""
    elif (( opt_c )); then
        echo -n "$base_cmd" | wl-copy
    else
        echo -n ".file \`$base_cmd\` -- " | wl-copy
    fi
}
