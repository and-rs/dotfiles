def _ai_has_provider_auth [provider: string] {
  let auth_path = ($env.HOME | path join ".pi" "agent" "auth.json")
  if not ($auth_path | path exists) {
    return false
  }

  try {
    let auth = (open $auth_path)
    ($auth | columns | any {|name| $name == $provider })
  } catch {
    false
  }
}

def _ai_summarize_model [] {
  let override = ($env.PI_SUMMARIZE_MODEL? | default "")
  if not ($override | is-empty) {
    return $override
  }

  if not (($env.OPENAI_API_KEY? | default "") | is-empty) {
    return "openai-codex/gpt-5.4-mini:off"
  }

  if (_ai_has_provider_auth "xai") {
    return "xai/grok-4.5:off"
  }

  if (_ai_has_provider_auth "openai-codex") or (_ai_has_provider_auth "openai") {
    return "openai-codex/gpt-5.4-mini:off"
  }

  if (_ai_has_provider_auth "github-copilot") {
    return "github-copilot/gpt-5-mini:off"
  }

  "openai-codex/gpt-5.4-mini:off"
}

def _ai_summarize_input [context: string prompt: string] {
  let max_chars = 62000
  let body = $"($context)\n\n($prompt)"
  if (($body | str length) <= $max_chars) {
    return $body
  }

  let prompt_len = ($prompt | str length)
  let budget = ($max_chars - $prompt_len - 2)
  if $budget <= 0 {
    return $prompt
  }

  let clipped = ($context | str substring 0..($budget - 1))
  $"($clipped)\n\n($prompt)"
}

# Keep the Pi executable and its non-interactive flags in one replaceable seam.
def _ai_run [label: string system_prompt: string model: string prompt: string] {
  if (which bun | is-empty) {
    error make {msg: "bun not found"}
  }

  (
    &spinner --msg $label --
    bun x --bun pi -ns -nt -nbt --no-session
    --system-prompt $system_prompt
    --model $model
    -p $prompt
  ) | str trim
}

def _ai_summarize [
  --label: string # Spinner label
  --prompt: string # Request prompt
  --context: string # Additional context
] {
  let system_prompt = "You follow instructions to the letter with no failure. you don't
  have to acknowledge that you understood the instructions. and your commit
  message output is always less than 60 characters long per line, you
  prioritize adding details to the commit message while staying true to the
  commit style seen previously."

  _ai_run $label $system_prompt (_ai_summarize_model) (_ai_summarize_input $context $prompt)
}

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
