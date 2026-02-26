# Main: git log viewer with fzf
export def glo [...args: string] {
  if (git rev-parse --is-inside-work-tree | complete | get exit_code) != 0 {
    error make {msg: "Not in a git repository"}
  }

  let log_format = "%C(auto)%h%d %s %C(blue)%C(italic)%cr%Creset"
  let fzf_flags = [
    ...$env.FORGIT_NU_DEFAULT_FLAGS
    "--prompt=Git log > "
    "--no-sort"
    "--tiebreak=index"
    "--preview=_forgit_log_preview {}"
    "--preview-window=right,50%"
    "--bind=enter:execute(_forgit_log_show {})"
    "--bind=ctrl-y:execute-silent(echo {} | grep -oE '\b[0-9a-fA-F]{7,40}\b' | head -n 1 | clip-copy)"
  ]

  git log --graph --color=always $"--format=($log_format)" ...$args | fzf ...$fzf_flags | ignore
}
