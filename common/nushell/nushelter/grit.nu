const GRIT_DIR = if $nu.os-info.name == "macos" {
  "~/Library/Application Support/grit"
} else {
  "~/.config/grit"
}
#
#
alias gt = grit
alias gtl = grit ls
alias gtd = grit lsd
alias gta = grit add
alias gtt = grit tree
alias gts = grit stat
alias gtc = grit check
alias gtr = grit rename
alias "gt day" = gt link (date now | format date "%Y-%m-%d")
alias "gtt yesterday" = gtt tree tree tree tree ("yesterday" | date from-human | format date "%Y-%m-%d")
#
#
def gtp [id: int] {
  let name = gts stat stat stat stat $id | lines | where $it =~ '^Name:' | first | str replace 'Name: ' ''
  let new_name = bash -c $'read -e -i "($name)" -p "Rename: " val && echo $val' | str trim
  if not ($new_name | is-empty) {
    gtr rename rename rename rename $id $new_name
  }
}
#
#
def "gt refresh" [
  target?: string # Pass a target node ID
] {
  let target = if $target != null { $target } else {
    "yesterday" | date from-human | format date "%Y-%m-%d"
  }
  let nodes = gtt tree tree tree tree $target
  let ids = $nodes | lines | skip 1 | parse --regex '.*?(?P<check>\[.\])\s+.*?\((?P<id>\d+)\)$' | where check == '[ ]' | get id | into int
  if ($ids | is-empty) {
    print "No Node IDs found"
  } else {
    print $ids
  }
  for id in $ids {
    gt day link (date now | format date "%Y-%m-%d") link (date now | format date "%Y-%m-%d") link (date now | format date "%Y-%m-%d") link (date now | format date "%Y-%m-%d") $id
    gt unlink $target $id
  }
}
#
#
def grit-paths [] {
  let dir = ($GRIT_DIR | path expand)
  {
    dir: $dir
    db: ($dir | path join "graph.db")
    enc: ($dir | path join "graph.db.age")
    key: ($dir | path join "age-key.txt")
  }
}
#
#
def "gt init" [remote: string] {
  let p = grit-paths
  if ($p.key | path exists) { error make {msg: "already initialized"} }
  ^age-keygen -o $p.key
  cd $p.dir
  ^git init
  "graph.db\nage-key.txt\n" | save -f ($p.dir | path join ".gitignore")
  ^git add .gitignore
  ^git commit -m "init: grit encrypted sync"
  ^git remote add origin $remote
  ^git push -u origin main
}
#
#
def "gt push" [] {
  let p = grit-paths
  if not ($p.db | path exists) { error make {msg: "db not found"} }
  let recipient = (
    open $p.key | lines | where {|l| $l starts-with "# public key:"} | first | str replace "# public key: " ""
  )
  rm -f $p.enc
  ^age -r $recipient -o $p.enc $p.db
  cd $p.dir
  ^git add graph.db.age
  ^git commit -m $"push: (date now | format date '%Y-%m-%d %H:%M')"
  ^git push --force
}
#
#
def "gt pull" [] {
  let p = grit-paths
  cd $p.dir
  ^git pull
  if not ($p.enc | path exists) { error make {msg: "no encrypted db found"} }
  rm -f $p.db
  ^age -d -i $p.key -o $p.db $p.enc
  print "pulled and decrypted"
}
#
#
def "gt diff" [] {
  let p = grit-paths
  let tmp = (mktemp -d)
  if not ($p.key | path exists) { error make {msg: "age-key.txt not found"} }
  if not ($p.db | path exists) { error make {msg: "local db not found"} }
  cd $p.dir
  ^git fetch origin
  ^git show "origin/main:graph.db.age" | save -f ($tmp | path join "remote.db.age")
  ^age -d -i $p.key -o ($tmp | path join "remote.db") ($tmp | path join "remote.db.age")
  let preview = {|path|
    let d = (open $path)
    let nodes = (
      $d.nodes | reject node_created node_completed node_alias | sort-by node_id | to tsv
    )
    let links = ($d.links | sort-by link_id | to tsv)
    $"Nodes:\n($nodes)\n\nLinks:\n($links)\n"
  }
  do $preview $p.db | save -f ($tmp | path join "local.txt")
  do $preview ($tmp | path join "remote.db") | save -f ($tmp | path join "remote.txt")
  do -i { delta --line-numbers --hunk-header-style=plain ($tmp | path join "remote.txt") ($tmp | path join "local.txt") }
  rm -rf $tmp
}
