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

  if (_ai_has_provider_auth "openai-codex") or (_ai_has_provider_auth "openai") {
    return "openai-codex/gpt-5.4-mini:off"
  }

  if (_ai_has_provider_auth "github-copilot") {
    return "github-copilot/gpt-5-mini:off"
  }

  "openai-codex/gpt-5.4-mini:off"
}

def _ai_summarize_input [context: string prompt: string] {
  let max_chars = 12000
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

export def _ai_summarize [
  --label: string # Spinner label
  --prompt: string # Request prompt
  --context: string # Additional context
] {
  if (which pi | is-empty) {
    error make {msg: "pi not installed — run: ai install"}
  }

  let sp = "you follow instructions to the letter with no failure. you don't
  have acknowledge that you understood the instructions. and your commit
  message output is always less than 60 characters long per line and concise."

  let model = (_ai_summarize_model)
  let input = (_ai_summarize_input $context $prompt)

  spinner $label {
    let result = (
      ^pi -ns -nt -nbt --no-session
      --system-prompt $sp
      --model $model
      -p $input
      | complete
    )
    if $result.exit_code != 0 {
      let stderr = ($result.stderr | str trim)
      error make {msg: $stderr}
    }
    $result.stdout
  } | str trim
}
