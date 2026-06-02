# git log viewer with fzf
export def glo [...args: string] {
  _forgit_check_repo
  let root = (_forgit_repo_root)
  let log_format = "%C(auto)%h%d %s %C(blue)%C(italic)%cr%Creset"
  let copy_bind = "--bind=ctrl-y:execute-silent(printf %s {} | grep -oE '[0-9a-fA-F]{7,40}' | head -n 1 | (command -v wl-copy >/dev/null 2>&1 && wl-copy || command -v xclip >/dev/null 2>&1 && xclip -selection clipboard || command -v pbcopy >/dev/null 2>&1 && pbcopy || cat >/dev/null))"
  let fzf_flags = [
    ...$env.FORGIT_NU_DEFAULT_FLAGS
    "--prompt=Git log > "
    "--no-sort"
    "--tiebreak=index"
    "--preview=_forgit_log_preview {}"
    "--preview-window=right,50%"
    "--bind=enter:execute(_forgit_log_show {})"
    $copy_bind
  ]

  git -C $root log --graph --color=always $"--format=($log_format)" ...$args | fzf ...$fzf_flags | ignore
}

