def "gh gs" [] { 
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
  gh copilot --model "claude-haiku-4.5" -p $"generate git commit message with previous commit style, be descriptive but keep it in short lines, DON'T use long lines per commit message line, if the command failed explain why. DON'T INCLUDE ANYTHING ELSE in the message. DON'T use any other command only the provided message \n --- (_ai_git_status)" 
}
