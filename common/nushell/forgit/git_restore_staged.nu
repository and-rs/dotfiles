export def grs [...files: string] {
  if (git rev-parse --is-inside-work-tree | complete | get exit_code) != 0 {
    error make {msg: "Not in a git repository"}
  }

  if ($files | is-not-empty) {
    git restore --staged ...$files
    git status -s
    return
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
    print "No staged changes to restore."
    return
  }

  let fzf_flags = [
    ...$env.FORGIT_NU_DEFAULT_FLAGS
    "--prompt=Git restore staged > "
    "--header-lines=1"
    "--delimiter=\t"
    "--preview=_forgit_diff_staged_preview '{2}'"
  ]

  let selected = (
    $entries
    | to tsv
    | fzf ...$fzf_flags
    | from tsv --noheaders
    | get column1
    | ansi strip
  )

  if ($selected | is-not-empty) {
    git restore --staged ...$selected
    git status -s
  } else {
    print "Nothing restored."
  }
}
