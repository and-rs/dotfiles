alias ai = aichat -r meaningful -s
alias aie = aichat -e
alias ai-gc = aichat -r meaningful --macro commit
alias ai-gcs = aichat -r meaningful --macro commit-staged
alias ai-rag = aichat -r indexer --rag

# The 'ret' Context Helper
def ret [
  --copy (-c) # Copy raw pipeline command to clipboard
  --preview (-p) # Filter and preview paths via ripgrep
  --json (-j) # Output raw JSON to stdout
  --select (-s) # Only select specific files with fzf
] {
  let paths = if $select {
    let selected = (^fd --type f | ^fzf --multi --padding=1,0,0,1 --prompt="Files for context > " --layout=reverse --height=100% | lines)
    if ($selected | is-empty) { print "No files selected"; return }
    $selected
  } else {
    [(pwd)]
  }

  let raw = (^yek ...$paths --json
    | from json
    | each { |r| { path: $r.filename, contents: $r.content } })

  if $preview {
    $raw | get path | print
    return
  }

  if $json {
    return ($raw | to json)
  }

  if $copy or $select {
    $raw | to json | clip-copy
    print $"(ansi green)Copied data to clipboard(ansi reset)"
    return
  }

  let cmd = $"yek '(pwd)' --json"
  $".file `($cmd)` -- " | clip-copy
  print $"(ansi green)Copied command to clipboard(ansi reset)"
}
