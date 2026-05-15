export def "ai squash" [] {
  let pi_count = (_ai_pi_commit_count | str trim | into int)
  if $pi_count == 0 {
    print $"(ansi yellow)no [PI] checkpoint commits at HEAD(ansi reset)"
    return
  }

  let dirty = (git status --porcelain | str trim)
  if not ($dirty | is-empty) {
    print $"(ansi red)worktree dirty(ansi reset) — commit, stash, or clean before squash"
    return
  }

  let base = (git rev-parse $"HEAD~($pi_count)" | str trim)
  let range = $"($base)..HEAD"
  let stat = (git --no-pager diff --stat --color=never $range | str trim)

  let context = (
    [
      $"Squashing ($pi_count) [PI] checkpoint commits."
      ""
      "Changed files:"
      (git --no-pager diff --name-status --color=never $range)
      ""
      "Diff stat:"
      $stat
      ""
      "Diff:"
      (git --no-pager diff --color=never $range)
    ] | str join "\n"
  )

  let answer = (try { input $"(ansi cyan)squash ($pi_count) [PI] commits? (ansi reset)[y/N] " } catch { "n" } | str trim | str downcase)
  if $answer != "y" { return }

  git reset --soft $base

  let prompt = "Output ONLY the raw commit message text. No backticks. No code fences. No markdown. No surrounding quotes. No preamble. No explanation. Raw text only. Mimic the style and format of recent commits exactly. Do not mention pi or checkpoints."
  let msg = (_ai_summarize --label "Summarizing" --context (_ai_git_status) --prompt $prompt)

  print ""
  print $msg

  let commit_answer = (try { input $"(ansi cyan)commit squashed changes? (ansi reset)[y/N] " } catch { "n" } | str trim | str downcase)
  if $commit_answer != "y" {
    print $"(ansi yellow)squash applied; staged changes kept; commit skipped(ansi reset)"
    return
  }

  git commit -e -m $msg
}
