def _pi_tools [] {
  "bash,grep,find,ls,exa_search,web_fetch,hashline_read,hashline_edit,file_create"
}

def ai [...args: string] {
  if ($args | length) == 0 {
    if (which pi | is-empty) {
      print "pi not installed. run: ai install"
      return
    }
    ^pi --tools (_pi_tools)
    return
  }

  ^pi --tools (_pi_tools) ...$args
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

def aip [prompt: string] {
  pi --tools (_pi_tools) --model "github-copilot/claude-haiku-4.5:off" -p --no-session $prompt
}

def _ai_pi_commit_count [] {
  mut count = 0
  for subject in (^git log --format=%s | lines) {
    if ($subject | str starts-with "[PI] checkpoint:") {
      $count = $count + 1
    } else {
      break
    }
  }
  $count
}

def "ai gs" [] {
  let pi_count = (_ai_pi_commit_count)
  if $pi_count > 0 {
    print $"Found ($pi_count) [PI] checkpoint commit(s). Run: ai squash"
    return
  }
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

  let prompt = "generate git commit message. mimic style of previous commits closely. use contents of attached staged diff. be descriptive but keep lines short. don't use long lines per commit message line. if command failed explain why. DON'T INCLUDE ANYTHING ELSE in the message. NO OPENING."
  let diff_context = (_ai_git_status)

  if (which pi | is-empty) {
    print "pi not installed. run: ai install"
    return
  }

  let prompt_file = (mktemp -t pi-gs-diff.XXXXXXXX)
  $diff_context | save --force $prompt_file
  let msg = (
    try {
      ^pi --tools (_pi_tools) --model "github-copilot/claude-haiku-4.5:off" -p --no-session $"@($prompt_file)" $prompt
    } catch {|err|
      rm --force $prompt_file
      error make {msg: $err.msg}
    } | str trim
  )
  rm --force $prompt_file
  print $msg

  print
  let answer = (input $"(ansi blue)commit? [y/N] " | str trim | str downcase)
  if $answer != "y" {
    return
  }

  ^git commit -e -m $msg
}

def "ai squash" [] {
  let pi_count = (_ai_pi_commit_count)
  if $pi_count == 0 {
    print "No [PI] checkpoint commits at HEAD."
    return
  }

  let dirty = (^git status --porcelain | str trim)
  if not ($dirty | is-empty) {
    print "Worktree dirty. Commit, stash, or clean changes before ai squash."
    return
  }

  if (which pi | is-empty) {
    print "pi not installed. run: ai install"
    return
  }

  let base = (^git rev-parse $"HEAD~($pi_count)" | str trim)
  let range = $"($base)..HEAD"
  let stat = (^git diff --stat $range)
  let names = (^git diff --name-status $range)
  let diff = (^git diff $range)
  let diff_context = ([
    $"Squash ($pi_count) local [PI] checkpoint commit(s)."
    ""
    "Changed files:"
    $names
    ""
    "Diff stat:"
    $stat
    ""
    "Diff:"
    $diff
  ] | str join "\n")

  let prompt = "generate final git commit message for squashed [PI] checkpoint commits. mimic previous commit style. be descriptive but concise. don't mention pi or checkpoint. DON'T INCLUDE ANYTHING ELSE in the message. NO OPENING."
  let prompt_file = (mktemp -t pi-squash-diff.XXXXXXXX)
  $diff_context | save --force $prompt_file
  let msg = (
    try {
      ^pi --tools (_pi_tools) --model "github-copilot/claude-haiku-4.5:off" -p --no-session $"@($prompt_file)" $prompt
    } catch {|err|
      rm --force $prompt_file
      error make {msg: $err.msg}
    } | str trim
  )
  rm --force $prompt_file

  print $msg
  print
  let answer = (input $"(ansi blue)squash ($pi_count) [PI] commit(s)? [y/N] " | str trim | str downcase)
  if $answer != "y" {
    return
  }

  ^git reset --soft $base
  ^git commit -e -m $msg
}
