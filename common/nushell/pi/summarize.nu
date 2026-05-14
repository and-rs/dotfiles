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

  spinner $label {
    let result = (
      ^pi -ns -nt -nbt --no-session
      --system-prompt $sp
      --model "github-copilot/gpt-5-mini:off"
      -p $"($context)\n\n($prompt)"
      | complete
    )
    if $result.exit_code != 0 {
      error make {msg: ($result.stderr | str trim)}
    }
    $result.stdout
  } | str trim
}
