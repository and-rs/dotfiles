let DB_PATH = $"($env.HOME)/.config/grit/graph.db"
let ENC_PATH = $"($env.HOME)/.config/grit/graph.db.age"
let KEY_PATH = $"($env.HOME)/.config/grit/age-key.txt"
let GRIT_DIR = $"($env.HOME)/.config/grit"
let SNAPSHOT_PATH = $"($env.HOME)/.config/grit/snapshot.txt"

def "grit init" [remote: string] {
  if ($KEY_PATH | path exists) { error make {msg: "already initialized"} }
  ^age-keygen -o $KEY_PATH
  cd $GRIT_DIR
  ^git init
  "graph.db\nage-key.txt\nsnapshot.txt\n" | save -f ($GRIT_DIR | path join ".gitignore")
  ^git add .gitignore
  ^git commit -m "init: grit encrypted sync"
  ^git remote add origin $remote
  ^git push -u origin main
}

def "grit save" [] {
  if not ($DB_PATH | path exists) { error make {msg: "db not found"} }
  let recipient = (open $KEY_PATH | lines | where {|l| $l starts-with "# public key:"} | first | str replace "# public key: " "")
  cd $GRIT_DIR
  try {
    ^git fetch origin
    let local = (^git rev-parse HEAD | str trim)
    let remote = (^git rev-parse origin/main | str trim)
    if $local != $remote {
      let behind = (^git log --oneline $"($local)..($remote)" | lines | length)
      if $behind > 0 {
        print "remote is ahead — pulling before save"
        ^git pull --rebase
        rm -f $DB_PATH
        ^age -d -i $KEY_PATH -o $DB_PATH $ENC_PATH
      }
    }
  }
  ^grit | save -f $SNAPSHOT_PATH
  rm -f $ENC_PATH
  ^age -r $recipient -o $ENC_PATH $DB_PATH
  ^git add graph.db.age
  ^git commit -m $"save: (date now | format date '%Y-%m-%d %H:%M')"
  try {
    ^git push
  } catch {
    print "push failed — run grit resolve"
  }
}

def "grit sync" [] {
  if ($SNAPSHOT_PATH | path exists) {
    let current = (^grit | str trim)
    let saved = (open $SNAPSHOT_PATH | str trim)
    if $current != $saved {
      error make {msg: "unsaved local changes — run grit save first"}
    }
  }
  cd $GRIT_DIR
  ^git pull
  if not ($ENC_PATH | path exists) { error make {msg: "no encrypted db to sync"} }
  rm -f $DB_PATH
  ^age -d -i $KEY_PATH -o $DB_PATH $ENC_PATH
  ^grit | save -f $SNAPSHOT_PATH
}

def "grit resolve" [] {
  cd $GRIT_DIR
  ^git fetch origin
  let local_enc = $ENC_PATH
  let remote_enc = "/tmp/grit-remote.db.age"
  let remote_db = "/tmp/grit-remote.db"
  ^git show origin/main:graph.db.age | save -f $remote_enc
  ^age -d -i $KEY_PATH -o $remote_db $remote_enc
  let local_dump = (^grit | str trim)
  let remote_dump = (sqlite3 $remote_db "SELECT node_id, node_name, node_alias, node_completed FROM nodes ORDER BY node_id" | str trim)
  print "=== LOCAL ==="
  print $local_dump
  print "\n=== REMOTE ==="
  print $remote_dump
  print "\n=== DIFF ==="
  $local_dump | save -f /tmp/grit-local.txt
  $remote_dump | save -f /tmp/grit-remote.txt
  do -i { ^diff --color=always /tmp/grit-local.txt /tmp/grit-remote.txt }
  let choice = (input "\nkeep [l]ocal or [r]emote? ")
  if $choice == "r" {
    print "\n--- local changes being discarded (re-add manually) ---"
    do -i { ^diff --color=always /tmp/grit-remote.txt /tmp/grit-local.txt }
    cp -f $remote_db $DB_PATH
  } else if $choice == "l" {
    print "\n--- remote changes being discarded (re-add manually) ---"
    do -i { ^diff --color=always /tmp/grit-local.txt /tmp/grit-remote.txt }
  } else {
    rm -f $remote_enc $remote_db /tmp/grit-local.txt /tmp/grit-remote.txt
    error make {msg: "invalid choice"}
  }
  rm -f $remote_enc $remote_db /tmp/grit-local.txt /tmp/grit-remote.txt
  let recipient = (open $KEY_PATH | lines | where {|l| $l starts-with "# public key:"} | first | str replace "# public key: " "")
  ^grit | save -f $SNAPSHOT_PATH
  rm -f $ENC_PATH
  ^age -r $recipient -o $ENC_PATH $DB_PATH
  ^git add graph.db.age
  ^git commit -m $"resolve: keep ($choice) (date now | format date '%Y-%m-%d %H:%M')"
  ^git push --force-with-lease
}

def "grit status" [] {
  if not ($SNAPSHOT_PATH | path exists) {
    print "no previous snapshot — run grit save first"
    return
  }
  let current = (^grit | str trim)
  let saved = (open $SNAPSHOT_PATH | str trim)
  if $current == $saved {
    print "no changes since last save"
  } else {
    $saved | save -f /tmp/grit-old.txt
    $current | save -f /tmp/grit-new.txt
    do -i { ^diff --color=always /tmp/grit-old.txt /tmp/grit-new.txt }
    rm -f /tmp/grit-old.txt /tmp/grit-new.txt
  }
}
