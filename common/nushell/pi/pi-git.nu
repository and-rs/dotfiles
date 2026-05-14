def _ai_summarize [label: string context: string prompt: string] {
  if (which pi | is-empty) {
    error make {msg: "pi not installed — run: ai install"}
  }
  spinner $label {
    let result = (
      ^pi -ns -nt -nbt -p
      --system-prompt "you follow instructions to the letter with no failure."
      --model "github-copilot/gpt-5-mini:off"
      --no-session $"($context)\n\n($prompt)"
      | complete
    )
    if $result.exit_code != 0 {
      error make {msg: ($result.stderr | str trim)}
    }
    $result.stdout
  } | str trim
}

def "ai gs" [] {
  let pi_count = (_ai_pi_commit_count | str trim | into int)
  if $pi_count > 0 {
    print $"(ansi yellow)($pi_count) [PI] commit(if $pi_count > 1 { "s" } else { "" }) pending — run: ai squash(ansi reset)"
    return
  }

  let staged = (^git diff --staged --stat | str trim)
  if ($staged | is-empty) {
    print $"(ansi yellow)nothing staged(ansi reset)"
    return
  }

  let prompt = "Output ONLY the raw commit message text. No backticks. No code fences. No markdown. No surrounding quotes. No preamble. No explanation. Raw text only. Mimic the style and format of recent commits exactly."
  let msg = (_ai_summarize "Summarizing" (_ai_git_status) $prompt)

  print ""
  print $msg

  let answer = (try { input $"(ansi cyan)commit? (ansi reset)[y/N] " } catch { "n" } | str trim | str downcase)
  if $answer != "y" { return }

  ^git commit -e -m $msg
}

def "ai squash" [] {
  let pi_count = (_ai_pi_commit_count | str trim | into int)
  if $pi_count == 0 {
    print $"(ansi yellow)no [PI] checkpoint commits at HEAD(ansi reset)"
    return
  }

  let dirty = (^git status --porcelain | str trim)
  if not ($dirty | is-empty) {
    print $"(ansi red)worktree dirty(ansi reset) — commit, stash, or clean before squash"
    return
  }

  let base = (^git rev-parse $"HEAD~($pi_count)" | str trim)
  let range = $"($base)..HEAD"
  let stat = (^git --no-pager diff --stat --color=never $range | str trim)

  let context = (
    [
      $"Squashing ($pi_count) [PI] checkpoint commits."
      ""
      "Changed files:"
      (^git --no-pager diff --name-status --color=never $range)
      ""
      "Diff stat:"
      $stat
      ""
      "Diff:"
      (^git --no-pager diff --color=never $range)
    ] | str join "\n"
  )

  let prompt = "Output ONLY the raw commit message text. No backticks. No code fences. No markdown. No surrounding quotes. No preamble. No explanation. Raw text only. Mimic the style and format of recent commits exactly. Do not mention pi or checkpoints."
  let msg = (_ai_summarize "Summarizing" $context $prompt)

  print ""
  print $msg

  let answer = (try { input $"(ansi cyan)squash ($pi_count) [PI] commits? (ansi reset)[y/N] " } catch { "n" } | str trim | str downcase)
  if $answer != "y" { return }

  ^git reset --soft $base
  ^git commit -e -m $msg
}
