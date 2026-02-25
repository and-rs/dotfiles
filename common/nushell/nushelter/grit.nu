let GRIT_DIR = if $nu.os-info.name == "macos" {
  $"($env.HOME)/Library/Application Support/grit"
} else {
  $"($env.HOME)/.config/grit"
}


let DB_PATH = ($GRIT_DIR | path join "graph.db")
let ENC_PATH = ($GRIT_DIR | path join "graph.db.age")
let KEY_PATH = ($GRIT_DIR | path join "age-key.txt")


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
  let name = gts $id
  | lines
  | where $it =~ '^Name:'
  | first
  | str replace 'Name: ' ''

  let new_name = bash -c $'read -e -i "($name)" -p "Rename: " val && echo $val' | str trim

  if not ($new_name | is-empty) {
    gtr $id $new_name
  }
}

def "gt refresh" [] {
    let yesterday = "yesterday" | date from-human | format date "%Y-%m-%d"
    let nodes = gtt $yesterday
    let ids = $nodes
        | lines
        | drop 1
        | parse --regex '.*?(?P<check>\[.\])\s+.*?\((?P<id>\d+)\)$'
        | where check == '[ ]'
        | get id
        | into int

    for id in $ids {
        gt day $id
        gt unlink $yesterday $id
    }
}

def "gt init" [remote: string] {
  if ($KEY_PATH | path exists) { error make {msg: "already initialized"} }
  ^age-keygen -o $KEY_PATH
  cd $GRIT_DIR
  ^git init
  "graph.db\nage-key.txt\n" | save -f ($GRIT_DIR | path join ".gitignore")
  ^git add .gitignore
  ^git commit -m "init: grit encrypted sync"
  ^git remote add origin $remote
  ^git push -u origin main
}

def "gt push" [] {
  if not ($DB_PATH | path exists) { error make {msg: "db not found"} }
  let recipient = (open $KEY_PATH | lines | where {|l| $l starts-with "# public key:"} | first | str replace "# public key: " "")
  rm -f $ENC_PATH
  ^age -r $recipient -o $ENC_PATH $DB_PATH
  cd $GRIT_DIR
  ^git add graph.db.age
  ^git commit -m $"push: (date now | format date '%Y-%m-%d %H:%M')"
  ^git push --force
}

def "gt pull" [] {
  cd $GRIT_DIR
  ^git pull
  if not ($ENC_PATH | path exists) { error make {msg: "no encrypted db found"} }
  rm -f $DB_PATH
  ^age -d -i $KEY_PATH -o $DB_PATH $ENC_PATH
  print "pulled and decrypted"
}


def "gt diff" [] {
  let tmp_remote_enc = "/tmp/grit-remote.db.age"
  let tmp_remote_db = "/tmp/grit-remote.db"
  let tmp_local_pview = "/tmp/grit-local-preview.txt"
  let tmp_remote_pview = "/tmp/grit-remote-preview.txt"

  if not ($DB_PATH | path exists) { error make {msg: "local db not found"} }

  cd $GRIT_DIR
  ^git fetch origin
  ^git show "origin/main:graph.db.age" | save -f $tmp_remote_enc
  ^age -d -i $KEY_PATH -o $tmp_remote_db $tmp_remote_enc

  let local = (open $DB_PATH)
  let remote = (open $tmp_remote_db)

  let local_nodes = ($local.nodes | reject node_created node_completed node_alias | sort-by node_id | to csv | qsv table)
  let remote_nodes = ($remote.nodes | reject node_created node_completed node_alias | sort-by node_id | to csv | qsv table)

  let local_links = ($local.links | sort-by link_id | to csv | qsv table)
  let remote_links = ($remote.links | sort-by link_id | to csv | qsv table)

  $"Nodes:\n($local_nodes)\n\nLinks:\n($local_links)\n" | save -f $tmp_local_pview
  $"Nodes:\n($remote_nodes)\n\nLinks:\n($remote_links)\n" | save -f $tmp_remote_pview

  let args = [$tmp_remote_pview $tmp_local_pview]
  do -i { delta --line-numbers --hunk-header-style=plain ...$args }

  # Cleanup
  rm -f $tmp_remote_enc $tmp_remote_db $tmp_local_pview $tmp_remote_pview
}
