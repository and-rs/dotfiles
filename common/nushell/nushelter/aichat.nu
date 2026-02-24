alias ai = aichat -r meaningful -s
alias aie = aichat -e
alias ai-gc = aichat -r meaningful --macro commit
alias ai-gcs = aichat -r meaningful --macro commit-staged
alias ai-rag = aichat -r indexer --rag

# The 'ret' Context Helper
# Examples:
#   ret --select --md                      # Pick files via FZF and copy as Markdown
#   ret --glob "*.rs" --stats              # Show count/size of all Rust files
#   ret --exclude "tests/*" --json         # Get JSON output excluding tests
#   ret --select --glob "src/*" --preview  # Filter FZF list to src/ and preview paths
#   ret --dry --exclude "node_modules"     # See what yek command would be generated
def ret [
  --copy (-c)    # Copy structured JSON data to clipboard
  --preview (-p) # List matched file paths only
  --json (-j)    # Output raw JSON to stdout
  --select (-s)  # Interactively pick files with fd + fzf
  --md (-m)      # Format output as markdown code blocks
  --glob (-g): string    # Filter files by glob pattern
  --exclude (-e): string # Exclude pattern passed to yek
  --stats        # Print file count and total byte size
  --dry          # Show resolved paths without reading contents
] {
  let paths = if $select {
    let cmd = if ($glob | is-empty) { "fd --type f" } else { $"fd --type f --glob '($glob)'" }
    let selected = (^bash -c $cmd 
      | ^fzf --multi --padding=1,0,0,1 --prompt="Files for context > " --layout=reverse --height=100% 
      | lines)
    if ($selected | is-empty) { print "No files selected"; return }
    $selected
  } else {
    [(pwd)]
  }

  let yek_args = if ($exclude | is-not-empty) {
    $paths | append ["--exclude" $exclude]
  } else {
    $paths
  }

  if $dry {
    print $"would run: yek ($yek_args | str join ' ') --json"
    return
  }

  let raw = (^yek ...$yek_args --json
    | from json
    | each { |r| { path: $r.filename, contents: $r.content } }
    | if ($glob | is-not-empty) and not $select {
        let pattern = ($glob | str replace '*' '')
        $in | where { |r| ($r.path | str contains $pattern) }
      } else { $in })

  if ($raw | is-empty) {
    print $"(ansi red)No files matched(ansi reset)"
    return
  }

  if $stats {
    let count = ($raw | length)
    let bytes = ($raw | each { |r| $r.contents | str length } | math sum)
    print $"(ansi cyan)($count) files, ($bytes | into filesize)(ansi reset)"
    return
  }

  if $preview {
    $raw | get path | each { |p| print $"(ansi yellow)($p)(ansi reset)" }
    return
  }

  let output = if $md {
    $raw | each { |r|
      let ext = ($r.path | path parse | get extension)
      $"## ($r.path)\n```($ext)\n($r.contents)\n```"
    } | str join "\n\n"
  } else {
    $raw | to json
  }

  if $json and not $md {
    return ($raw | to json)
  }

  if $copy or $select or $md or $json {
    $output | clip-copy
    print $"(ansi green)Copied ($raw | length) files to clipboard(ansi reset)"
    return
  }

  let cmd = $"yek '(pwd)' --json"
  $".file `($cmd)` -- " | clip-copy
  print $"(ansi green)Copied command to clipboard(ansi reset)"
}
