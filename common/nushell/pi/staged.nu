export def "ai gs" [] {
  let pi_count = (_ai_pi_commit_count | str trim | into int)
  if $pi_count > 0 {
    print $"(ansi yellow)($pi_count) [PI] commit(if $pi_count > 1 { "s" } else { "" }) pending — run: ai squash(ansi reset)"
    return
  }

  let staged = (git diff --staged --stat | str trim)
  if ($staged | is-empty) {
    print $"(ansi yellow)nothing staged(ansi reset)"
    return
  }

  let prompt = "Output ONLY the raw commit message text. No backticks. No code fences. No markdown. No surrounding quotes. No preamble. No explanation. Raw text only. Mimic the style and format of recent commits exactly."
  let msg = (_ai_summarize --label "Summarizing" --context (_ai_git_status) --prompt $prompt)

  print ""
  print $msg

  let answer = (try { input $"(ansi cyan)commit? (ansi reset)[y/N] " } catch { "n" } | str trim | str downcase)
  if $answer != "y" { return }

  git commit -e -m $msg
}
