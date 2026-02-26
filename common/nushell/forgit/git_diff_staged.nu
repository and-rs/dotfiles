export def gds [] {
  if (git rev-parse --is-inside-work-tree | complete | get exit_code) != 0 {
    error make {msg: "Not in a git repository"}
  }

  let entries = (
    git status --porcelain | lines | parse --regex '^(?P<x>.)(?P<y>.) (?P<path>.*)$' 
    | where x != " " and x != "?" | each {|row|
      let clean_path = if ($row.path | str contains ' -> ') {
        $row.path | split row ' -> ' | last
      } else {
        $row.path
      }
      {
        status: $"(ansi reset)[(ansi green)($row.x)(ansi reset)]",
        path: $"(ansi reset)($clean_path)"
      }
    }
  )

  if ($entries | is-empty) {
    print "No staged changes."
    return
  }

  let fzf_flags = [
    ...$env.FORGIT_NU_DEFAULT_FLAGS
    "--prompt=Git diff staged > "
    "--delimiter=\t"
    "--header-lines=1"
    "--preview=_forgit_diff_staged_preview {2}"
    "--bind=enter:execute(_forgit_diff_staged_show {2})"
  ]

  $entries | to tsv | fzf ...$fzf_flags | ignore
}
