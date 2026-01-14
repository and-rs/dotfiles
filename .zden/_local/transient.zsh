# Custom transient prompt because p10k allows for less customization
_compact_prompt() {
    PROMPT='%F{cyan}>>%f '
    zle .reset-prompt
}

_zle_line_finish() {
    _compact_prompt
}

zle -N zle-line-finish _zle_line_finish
