use clip.nu

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
  let excludes = [
    node_module
    .git
    .cache
    .npm
    .mozilla
    .meteor
    .nv
  ]
  let cmd_args = $excludes | each {|it| ["--exclude" $it] } | flatten
  let selected_dir = (
    fd --type d --hidden ...$cmd_args
    | fzf --prompt="choose directory > " --reverse --info="right" --padding="1,0,0,1"
    | str trim
  )
  if ($selected_dir | is-not-empty) { cd $selected_dir } else { print "No directory selected." }
}
