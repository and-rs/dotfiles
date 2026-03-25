# Aliases
alias g = git
alias gc = git commit
alias gl = git log --oneline -n 10
alias gs = git status
alias gpl = git pull
alias gph = git push
#
# New Branch Flow: switch main -> pull -> switch -c new_branch
def gnewbranch [] {
  ^git switch main
  ^git pull origin main
  ^git switch -c
}
#
# Prune Flow
def gprune [] {
  ^git pull origin main
  ^git fetch --prune
}
#
# Push current branch
def gpbranch [] { ^git push -u origin HEAD }
#
# Create PR
def "gpr create" [branch?: string] {
  let current = if ($branch != null) { $branch } else {
    ^git symbolic-ref --short HEAD | str trim
  }
  if ($current | is-empty) { error make {msg: "Not in a git repo or no branch found"} }
  print $"Pushing ($current) and creating PR..."
  ^git push -u origin $current
  ^gh pr create --base main --head $current --fill
}
#
# Merge PR
def "gpr merge" [branch?: string] {
  let current = if ($branch != null) { $branch } else {
    ^git symbolic-ref --short HEAD | str trim
  }
  if ($current | is-empty) { error make {msg: "Not in a git repo or no branch found"} }
  print $"Merging PR for ($current)..."
  ^gh pr merge $current --merge --delete-branch
}
#
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
#
# Interactive Repo Delete (Nushell Style)
def gh-repo-delete [] {
  let repos = (^gh repo list --json owner,name,visibility | from json)
  if ($repos | is-empty) {
    print "No repos found."
    return
  }
  let selection = (
    $repos | each { |r| $"($r.name)\t($r.owner.login)\t($r.visibility)" } | str join (char newline) | ^fzf --multi --reverse --header="Name\tOwner\tVisibility"
  )
  if ($selection | is-empty) {
    print "No repos selected."
    return
  }
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
