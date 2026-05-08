alias ai = pi

def "ai gs" [] {
  let entries = (
    git status --porcelain | lines | parse --regex '^(?P<x>.)(?P<y>.) (?P<path>.*)$' | where x != " " and x != "?" | each {|row|
      let clean_path = if ($row.path | str contains ' -> ') {
        $row.path | split row ' -> ' | last
      } else {
        $row.path
      }
      {
        status: $"(ansi reset)[(if $row.x == "D" { ansi red } else { ansi green })($row.x)($row.y)(ansi reset)]"
        path: $"(ansi reset)($clean_path)"
      }
    }
  )
  if ($entries | is-empty) {
    print "No staged changes."
    return
  }

  let prompt = $"generate git commit message. mimic style of previous commits
  closely. use contents of current staged diff. be descriptive but keep lines
  short. don't use long lines per commit message line. if command failed
  explain why. DON'T INCLUDE ANYTHING ELSE in the message. NO OPENING.
  ---
  (_ai_git_status)"

  pi -p $prompt
}
