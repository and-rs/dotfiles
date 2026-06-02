# git diff selector with fzf
export def gd [] {
  _forgit_check_repo
  let root = (_forgit_repo_root)
  let entries = (
    git -C $root status --porcelain -u
    | lines
    | parse --regex '^(?P<x>.)(?P<y>.) (?P<path>.*)$'
    | where x == " " or x == "?"
    | each {|row|
      let clean_path = if ($row.path | str contains ' -> ') {
        $row.path | split row ' -> ' | last
      } else {
        $row.path
      }
      {
        status: $"(ansi reset)[(ansi yellow)($row.x)(if $row.y == "D" { ansi red })($row.y)(ansi reset)]"
        path: $clean_path
      }
    }
  )

  if ($entries | is-empty) {
    print "No unstaged changes."
    return
  }

  let fzf_flags = [
    ...$env.FORGIT_NU_DEFAULT_FLAGS
    "--prompt=Git diff unstaged > "
    "--delimiter=\t"
    "--header-lines=1"
    "--preview=_forgit_diff_preview {2}"
    "--bind=enter:execute(_forgit_diff_show {2})"
  ]

  $entries | to tsv | fzf ...$fzf_flags | ignore
}

