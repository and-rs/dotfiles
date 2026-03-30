alias g = git
alias gc = git commit
alias gl = git log --oneline -n 10
alias gs = git status
alias gpl = git pull
alias gph = git push

# Interactive Repo Delete
def gh-repo-delete [] {
  let repos = (^gh repo list --json owner,name,visibility | from json)
  if ($repos | is-empty) {
    print "No repos found."
    return
  }
  let selection = (
    $repos | each {|r| $"($r.name)\t($r.owner.login)\t($r.visibility)" } | str join (char newline) | ^fzf --multi --reverse --header="Name\tOwner\tVisibility"
  )
  if ($selection | is-empty) {
    print "No repos selected."
    return
  }
  let to_delete = $selection | lines | split column "\t" name owner visibility
  let count = $to_delete | length
  print $"(char newline)About to delete ($count) repositories:"
  print ($to_delete | table)
  print $"(char newline)(ansi red)WARNING: This action is permanent.(ansi reset)"
  let confirmation = (input "Type DELETE to confirm: ")
  if $confirmation != "DELETE" {
    print "Aborted."
    return
  }
  $to_delete | each {|repo|
    print $"Deleting ($repo.owner)/($repo.name)..."
    ^gh repo delete --yes $"($repo.owner)/($repo.name)"
  }
}
