def _ai_without_aws_env [command: closure] {
  with-env {
    AWS_PROFILE: null
    AWS_ACCESS_KEY_ID: null
    AWS_SECRET_ACCESS_KEY: null
    AWS_BEARER_TOKEN_BEDROCK: null
    AWS_REGION: null
  } {
    do $command
  }
}

export def --wrapped "ai" [...args] {
  _ai_without_aws_env { bun x --bun pi ...$args }
}

def _ai_agent_dir [] {
  (
    $env.PI_CODING_AGENT_DIR?
    | default ($env.HOME | path join ".pi" "agent")
    | path expand
  )
}

def _ai_summarize_model_path [] {
  _ai_agent_dir | path join "commit-message-model"
}

export def "ai bootstrap" [manifest: path extensions_dir: path] {
  let agent_dir = (_ai_agent_dir)
  let settings_path = ($agent_dir | path join "settings.json")
  mkdir $agent_dir

  let settings = if ($settings_path | path exists) {
    open $settings_path
  } else {
    {}
  }
  $settings | upsert npmCommand ["bun"] | save --force $settings_path

  bun install --cwd $extensions_dir --frozen-lockfile

  let packages = (
    open $manifest
    | get --optional piBootstrap.packages
    | default []
  )
  for package in $packages {
    ai install $package
  }
}

def _ai_select_summarize_model [] {
  if (which bun | is-empty) {
    error make {msg: "bun not found"}
  }

  if (which fzf | is-empty) {
    error make {msg: "fzf not found; commit model selection is required"}
  }

  let model_list = (ai --list-models | complete)
  if $model_list.exit_code != 0 {
    let details = ($model_list.stderr | str trim)
    if ($details | is-empty) {
      error make {msg: $"Pi model listing failed with exit code ($model_list.exit_code)"}
    }
    error make {msg: $"Pi model listing failed: ($details)"}
  }

  let models = (
    try {
      $model_list.stdout | from ssv
    } catch {|err|
      error make {msg: $"Could not parse Pi model list: ($err.msg)"}
    }
  )
  if ($models | is-empty) {
    error make {msg: "Pi returned no available models"}
  }

  let columns = ($models | columns)
  if not ("provider" in $columns) or not ("model" in $columns) {
    error make {msg: "Pi model list must include provider and model columns"}
  }

  let selection = (
    $models
    | to tsv
    | fzf --delimiter=(char tab) --header-lines=1 --prompt=" Commit model > " --padding=1,0,0,1 --height=100%
    | complete
  )
  if $selection.exit_code != 0 {
    if $selection.exit_code == 1 or $selection.exit_code == 130 {
      error make {msg: "No commit model selected; selection is required"}
    }
    let details = ($selection.stderr | str trim)
    error make {msg: $"fzf failed with exit code ($selection.exit_code): ($details)"}
  }

  let fields = ($selection.stdout | str trim | split row (char tab))
  if ($fields | length) < 2 {
    error make {msg: "Could not read provider and model from fzf selection"}
  }

  let provider = ($fields | get 0 | str trim)
  let model = ($fields | get 1 | str trim)
  if ($provider | is-empty) or ($model | is-empty) {
    error make {msg: "Could not read provider and model from fzf selection"}
  }

  let selected_model = $"($provider)/($model):off"
  let agent_dir = (_ai_agent_dir)
  mkdir $agent_dir
  $selected_model | save --force (_ai_summarize_model_path)
  $selected_model
}

def _ai_summarize_model [] {
  let model_path = (_ai_summarize_model_path)
  if ($model_path | path exists) {
    let selected_model = (open $model_path | str trim)
    if not ($selected_model | is-empty) {
      return $selected_model
    }
  }

  _ai_select_summarize_model
}

export def "ai summarize-model" [] {
  _ai_select_summarize_model
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

  let result = (
    _ai_without_aws_env {
      &spinner --structured --quiet-cancel --msg $label -- bun x --bun pi -ns -nt -nbt --no-session --system-prompt $system_prompt --model $model -p $prompt
    }
  )

  let structured = (try { $result | from json } catch { null })
  if ($structured != null) {
    if ($structured.cancelled? | default false) {
      return $structured
    }
    return ($structured.stdout | str trim)
  }

  $result | str trim
}

def _ai_summarize [
  --label: string # Spinner label
  --prompt: string # Request prompt
  --context: string # Additional context
] {
  let system_prompt = "Generate commit messages from staged changes only. Follow the
  requested Conventional Commits format; never use commit history. Output exactly
  one commit message and nothing else. Do not add a preamble, label, alternatives,
  explanation, Markdown, code fences, or quotation marks. Begin with the commit
  header and keep every line under 60 characters."

  _ai_run $label $system_prompt (_ai_summarize_model) (_ai_summarize_input $context $prompt)
}

def _ai_summarize_cancelled [err: any] {
  let message = ($err.msg? | default "" | str lowercase)
  $message =~ "interrupt|sigint|cancel"
}

def _ai_was_cancelled [value: any] {
  try { $value.cancelled? | default false } catch { false }
}

export def "air" [] {
  ai -r
}

export def "ai gs" [] {
  let staged = (git diff --staged | str trim)
  if ($staged | is-empty) {
    print $"(ansi yellow)nothing staged(ansi reset)"
    return
  }

  let base_prompt = "Output exactly one Conventional Commit message based solely on
  the staged diff. Return only the message: no preamble, label, alternatives,
  explanation, Markdown, code fences, or quotation marks. Format the header as
  <type>(<scope>): <imperative summary>; scope is optional. Choose an accurate
  type such as feat, fix, refactor, perf, docs, test, build, ci, chore, or revert.
  Keep every line under 60 characters. Add a concise body only when needed to
  capture other meaningful changes. Mark breaking changes with ! and a BREAKING
  CHANGE: footer. Cover staged changes broadly, do not invent details, and never
  use commit history. Describe documentation and text-only changes briefly."

  mut msg = (
    try {
      _ai_summarize --label "Summarizing" --context (&ai_git_status) --prompt $base_prompt
    } catch {|err|
      if (_ai_summarize_cancelled $err) { return }
      error make {msg: $err.msg}
    }
  )

  if (_ai_was_cancelled $msg) {
    return
  }

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
      try {
        (
          _ai_summarize
          --label "Revising"
          --context (&ai_git_status)
          --prompt $revise_prompt
        )
      } catch {|err|
        if (_ai_summarize_cancelled $err) { return }
        error make {msg: $err.msg}
      }
    )

    if (_ai_was_cancelled $msg) {
      return
    }
  }
}
