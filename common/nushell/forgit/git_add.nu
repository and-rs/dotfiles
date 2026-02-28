# git add selector with fzf
export def ga [...files: string] {
  _forgit_check_repo

  if ($files | is-not-empty) {
    git add ...$files
    git status -s
    return
  }

  let entries = (
    ^git status --porcelain -u
    | lines
    | parse --regex '^(?P<x>.)(?P<y>.) (?P<path>.*)$'
    | where y != " "
    | each {|row|
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
    print "Nothing to add."
    return
  }

  let fzf_flags = [
    ...$env.FORGIT_NU_DEFAULT_FLAGS
    "--delimiter=\t"
    "--header-lines=1"
    "--prompt=Git add > "
    "--preview=_forgit_add_preview '{2}'"
  ]

  let selected = ($entries | to tsv | fzf ...$fzf_flags | from tsv --noheaders | get column1)

  if ($selected | is-not-empty) {
    git add ...$selected
    git status -s
  } else {
    print "Nothing to add."
  }
}
