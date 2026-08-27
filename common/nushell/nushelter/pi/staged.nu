export def "ai gs" [] {
  let staged = (git diff --staged | str trim)
  if ($staged | is-empty) {
    print $"(ansi yellow)nothing staged(ansi reset)"
    return
  }

  let base_prompt = "Output ONLY the raw commit message text. No backticks. No
  code fences. No markdown. No surrounding quotes. No preamble. No explanation.
  Raw text only. Mimic the style and format of recent commits exactly. Do not
  over-focus on one file or one narrow part of the diff. Prefer breadth across
  staged files. Keep every line under 60 characters. Do not go deep into text
  changes like READMEs, only a quick content description"

  mut msg = (
    _ai_summarize --label "Summarizing" --context (&ai_git_status) --prompt $base_prompt
  )

  loop {
    print ""
    print $msg

    let answer = (try { input $"(ansi cyan)commit? (ansi reset)[y]es / [r]evise / [n]o: " } catch { "n" } | str trim | str lowercase)
    if ($answer in ["" "y" "yes"]) {
      git commit -e -m $msg
      return
    }

    if not ($answer in ["r" "revise"]) { return }

    let revision = (try { input $"(ansi cyan)revise how? (ansi reset)" } catch { "" } | str trim)

    if ($revision | is-empty) { continue }

    let revise_prompt = $"($base_prompt)\n\nRevise this commit message using
    the requested change. Preserve accurate facts from the staged
    diff.\n\nCurrent commit message:\n($msg)\n\nRequested change:\n($revision)"

    $msg = (
      _ai_summarize
      --label "Revising"
      --context (&ai_git_status)
      --prompt $revise_prompt
    )
  }
}
