alias gt = grit
alias gtl = grit ls
alias gtd = grit lsd
alias gta = grit add
alias gtt = grit tree
alias gts = grit stat
alias gtc = grit check
alias gtr = grit rename
alias "gt day" = gt link (date now | format date "%Y-%m-%d")
alias "gtt yesterday" = gtt ("yesterday" | date from-human | format date "%Y-%m-%d")

def gtp [id: int] {
  let name = gts $id | lines | where $it =~ 'Name:' | first | str replace 'Name: ' ''
  let new_name = bash -c $'read -e -i "($name)" -p "Rename: " val && echo $val' | str trim
  if not ($new_name | is-empty) {
    gtr $id $new_name
  }
}

def "gt refresh" [
  target?: string # Pass a target node ID
] {
  let target = if $target != null { $target } else {
    "yesterday" | date from-human | format date "%Y-%m-%d"
  }
  let nodes = gtt $target
  let ids = $nodes | lines | skip 1 | parse --regex '.*?(?P<check>\[.\])\s+.*?\((?P<id>\d+)\)$' | where check == '[ ]' | get id | into int
  if ($ids | is-empty) {
    print "No Node IDs found"
  } else {
    print $ids
  }
  for id in $ids {
    gt link (date now | format date "%Y-%m-%d") $id
    gt unlink $target $id
  }
}
