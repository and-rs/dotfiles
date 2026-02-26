# Aliases
alias g = git
alias gc = git commit
alias gl = git log --oneline -n 10
alias gs = git status
alias gpl = git pull
alias gph = git push

# Functions

# TODO; needs rework to fit nushell flow
# Wrapper to auto-stash before hard resets
# def git [subcommand?: string, ...args] {
#    if $subcommand == "reset" and ($args | first) == "--hard" {
#       let stash_msg = $"auto-stash before hard reset (date now | format date '%Y-%m-%dT%H:%M:%S')"
#       ^git stash -u -k -m $stash_msg
#       ^git reset --hard ...($args | skip 1)
#       ^git stash list | head -n1
#    } else {
#       if ($subcommand != null) {
#          ^git $subcommand ...$args
#       } else {
#          ^git
#       }
#    }
# }

# New Branch Flow: switch main -> pull -> switch -c new_branch
def gnewbranch [] {
   ^git switch main; ^git pull origin main; ^git switch -c
}

# Prune Flow
def gprune [] {
   ^git pull origin main; ^git fetch --prune
}

# Push current branch
def gpbranch [] {
   ^git push -u origin HEAD
}

# Create PR
def "gpr create" [branch?: string] {
   let current = if ($branch != null) { $branch } else { ^git symbolic-ref --short HEAD | str trim }
   if ($current | is-empty) { error make {msg: "Not in a git repo or no branch found"} }
   print $"Pushing ($current) and creating PR..."
   ^git push -u origin $current
   ^gh pr create --base main --head $current --fill
}

# Merge PR
def "gpr merge" [branch?: string] {
   let current = if ($branch != null) { $branch } else { ^git symbolic-ref --short HEAD | str trim }
   if ($current | is-empty) { error make {msg: "Not in a git repo or no branch found"} }
   print $"Merging PR for ($current)..."
   ^gh pr merge $current --merge --delete-branch
}

# Sync Feature Branch
def gsync [] {
   let current = (^git symbolic-ref --short HEAD | str trim)
   if ($current == "main" or $current == "master") {
      print $"(ansi red)Cannot gsync on ($current). Use 'git pull' instead.(ansi reset)"
      return
   }
   print $"Syncing ($current)..."
   ^git switch main
   ^git pull origin main
   ^git branch -d $current
   ^git fetch --prune
   print $"(ansi green)gsync completed.(ansi reset)"
}

# Switch Work Account
def git-work-account [] {
   ^git config user.name 'juan-lsource'
   ^git config user.email 'juan.bautista@logicsource.com'
   print $"User: (^git config --get user.name)"
   print $"Email: (^git config --get user.email)"
}

# Interactive Repo Delete (Nushell Style)
def gh-repo-delete [] {
   let repos = (^gh repo list --json owner,name,visibility | from json)
   if ($repos | is-empty) { print "No repos found."; return }
   let selection = (
      $repos 
      | each { |r| $"($r.name)\t($r.owner.login)\t($r.visibility)" } 
      | str join (char newline)
      | ^fzf --multi --reverse --header="Name\tOwner\tVisibility"
   )
   if ($selection | is-empty) { print "No repos selected."; return }
   let to_delete = ($selection | lines | split column "\t" name owner visibility)
   let count = ($to_delete | length)
   print $"(char newline)About to delete ($count) repositories:"
   print ($to_delete | table)
   print $"(char newline)(ansi red)WARNING: This action is permanent.(ansi reset)"
   let confirmation = (input "Type DELETE to confirm: ")
   if $confirmation != "DELETE" {
      print "Aborted."
      return
   }
   $to_delete | each { |repo|
      print $"Deleting ($repo.owner)/($repo.name)..."
      ^gh repo delete --yes $"($repo.owner)/($repo.name)"
   }
}
