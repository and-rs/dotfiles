# git restore --staged selector with fzf
export def grs [...files: string] {
  _forgit_check_repo
  if ($files | is-not-empty) {
    git restore --staged ...$files
    git status -s
    return
  }

  let root = (_forgit_repo_root)
  let entries = (
    git -C $root status --porcelain
    | lines
    | parse --regex '^(?P<x>.)(?P<y>.) (?P<path>.*)$'
    | where x != " " and x != "?"
    | each {|row|
      let clean_path = if ($row.path | str contains ' -> ') {
        $row.path | split row ' -> ' | last
      } else {
        $row.path
      }
      {
        status: $"(ansi reset)[(ansi green)($row.x)($row.y)(ansi reset)]"
        path: $clean_path
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
    "--preview=_forgit_diff_preview -s '{2}'"
  ]

  let selected = (
    $entries
    | to tsv
    | fzf ...$fzf_flags
    | from tsv --noheaders
    | get column1
    | each {|path| $path | ansi strip }
  )

  if ($selected | is-not-empty) {
    git -C $root restore --staged -- ...$selected
    git -C $root status -s
  } else {
    print "Nothing restored."
  }
}

