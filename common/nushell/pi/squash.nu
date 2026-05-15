export def "ai squash" [] {
  let pi_count = (_ai_pi_commit_count | str trim | into int)
  if $pi_count == 0 {
    print $"(ansi yellow)no [PI] checkpoint commits at HEAD(ansi reset)"
    return
  }

  git stash

  let base = (git rev-parse $"HEAD~($pi_count)" | str trim)
  let range = $"($base)..HEAD"
  let stat = (git --no-pager diff --stat --color=never $range | str trim)

  git reset --soft $base

  print $"(ansi red)> squashed bitch\n"
}
