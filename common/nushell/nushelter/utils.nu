use clip.nu

# Select files at a specific depth and copy their absolute paths.
def filepath [
  --depth (-d): int = 1 # The exact depth to search (default: 1)
] {
  if (which fd | is-empty) { error make {msg: "'fd' is required"} }
  if (which fzf | is-empty) { error make {msg: "'fzf' is required"} }
  let selection = (
    ^fd --exact-depth $depth --absolute-path
    | ^fzf --multi --padding=1,0,0,1 --prompt="Select file(s) > " --layout=reverse
  )
  if ($selection | is-empty) {
    print "No file selected."
    return
  }
  let paths = ($selection | lines)
  let count = ($paths | length)
  $selection | clip-copy
  print $"Copied ($count) file path\(s\) to clipboard."
}

# Copy directory tree structure to clipboard
def dirtree [] {
  if (which eza | is-empty) { error make {msg: "'eza' is required"} }
  let tree_output = (^eza -Ta --git-ignore)
  let formatted = $"```\n($tree_output)\n```"
  $formatted | clip-copy
  print $tree_output
  print $"(ansi green)eza tree output copied to clipboard! (ansi reset)"
}

# Interactive Directory Picker
def --env f [] {
  let excludes = [ node_module .git .cache .npm .mozilla .meteor .nv ]
  let cmd_args = ($excludes | each { |it| ["--exclude", $it] } | flatten)
  let selected_dir = (^fd --type d --hidden ...$cmd_args | ^fzf --prompt="choose directory > " --reverse --info="right" --padding="1,0,0,1" | str trim)
  if ($selected_dir | is-not-empty) { cd $selected_dir } else { print "No directory selected." }
}
