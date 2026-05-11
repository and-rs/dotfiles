def ai [...args: string] {
  if ($args | length) == 0 {
    if (which pi | is-empty) {
      print "pi not installed. run: ai install"
      return
    }
    ^pi
    return
  }

  ^pi ...$args
}

def "ai install" [...args: string] {
  if (which npm | is-empty) {
    print "npm not found"
    return
  }

  if ($args | is-empty) {
    print "ai install > installing pi"
    ^npm install -g @earendil-works/pi-coding-agent
    return
  }

  if (which pi | is-empty) {
    print "ai install > installing pi"
    ^npm install -g @earendil-works/pi-coding-agent
  }

  ^pi install ...$args
}

def "ai bootstrap" [name?: string] {
  if (which npm | is-empty) {
    print "npm not found"
    return
  }

  let extensions_dir = ($env.HOME | path join ".pi" "agent" "extensions")
  if not ($extensions_dir | path exists) {
    print "no pi extensions dir"
    return
  }

  let dirs = (
    ls $extensions_dir
    | where type == dir
    | get name
    | where {|dir|
      let package_json = ($dir | path join "package.json")
      if not ($package_json | path exists) {
        false
      } else if ($name | is-empty) {
        true
      } else {
        (($dir | path basename) == $name)
      }
    }
  )

  if ($dirs | is-empty) {
    print "no matching pi extension packages"
    return
  }

  for dir in $dirs {
    print $"pi bootstrap > npm install (($dir | path basename))"
    do {
      cd $dir
      ^npm install
    }
  }
}

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

  if (which pi | is-empty) {
    print "pi not installed. run: ai install"
    return
  }

  let msg = (^pi --model "claude-haiku" -p --no-session $prompt | str trim)
  print $msg

  print "\n"
  let answer = (input $"(ansi blue)commit? [y/N] " | str trim | str downcase)
  if $answer != "y" {
    return
  }

  ^git commit -e -m $msg
}
