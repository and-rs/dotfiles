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
] {
  let current_path = (pwd)
  let yek_str = $"yek '($current_path)' --json"
  let jq_str = "jq '[.[] | { path: .filename, contents: .content }]'"
  let pipe_str = $"($yek_str) | ($jq_str)"

  if $preview {
    ^bash -c $"($pipe_str) | rg '\"path\"'"
    return
  }

  if $json {
    return (^bash -c $pipe_str | jq)
  }

  let content_to_copy = if $copy { $pipe_str } else { $".file `($pipe_str)` -- " }
  $content_to_copy | clip-copy
  print $"(ansi green)Copied to clipboard:(ansi reset) ($content_to_copy)"
}
