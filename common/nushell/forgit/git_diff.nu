# git diff selector with fzf
export def gd [] {
  _forgit_check_repo

  let entries = (
    git status --porcelain | lines | parse --regex '^(?P<x>.)(?P<y>.) (?P<path>.*)$'
    | where x == " " or x == "?" | each {|row|
      let clean_path = if ($row.path | str contains ' -> ') {
        $row.path | split row ' -> ' | last
      } else {
        $row.path
      }
      {
        status: $"(ansi reset)[(ansi yellow)($row.x)(if $row.y == "D" {ansi red})($row.y)(ansi reset)]",
        path: $"(ansi reset)($clean_path)"
      }
    }
  )

  if ($entries | is-empty) {
    print "No unstaged changes."
    return
  }

  let fzf_flags = [
    ...$env.FORGIT_NU_DEFAULT_FLAGS
    "--prompt=Git diff staged > "
    "--delimiter=\t"
    "--header-lines=1"
    "--preview=_forgit_diff_preview {2}"
    "--bind=enter:execute(_forgit_diff_show {2})"
  ]

  $entries | to tsv | fzf ...$fzf_flags | ignore
}
