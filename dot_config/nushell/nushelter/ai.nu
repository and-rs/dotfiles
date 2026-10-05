const MODEL_PATH: path = ("~/.config/opencode/commit-message-model" | path expand)

export def --wrapped main [...args] {
  opencode ...$args
}

export def "ai sd" [s: string] {
  opencode session delete $s
}

export def "ai 1s" [prompt: string] {
  let model = (open $MODEL_PATH | str trim | split row "/")
  let request = {
    input: {
      model: {
        providerID: ($model | get 0)
        id: ($model | skip 1 | str join "/")
      }
      prompt: $prompt
    }
  } | to json -r
  opencode api post /api/rpc/commit-message/generate --data $request | from json | get output | get text
}

export def "ai summarize-model" [] {
  let model = (
    opencode models
    | fzf
    --tmux
    --prompt=" Commit model > "
    --padding=1,0,0,1
    --height=100%
  )
  $model | save --force $MODEL_PATH
  $model
}

export def "ai gs" [] {
  let staged = (&ai_git_status | str trim)
  if ($staged | is-empty) {
    print $"(ansi yellow)nothing staged(ansi reset)"
    return
  }

  if (try { open $MODEL_PATH } | is-empty) {
    ai summarize-model
  }
  let model = (open $MODEL_PATH | str trim | split row "/")

  let system_prompt = "Generate commit messages from staged changes only.
  Follow the requested Conventional Commits format; never use commit history.
  Output exactly one commit message and nothing else. Do not add a preamble,
  label, alternatives, explanation, Markdown, code fences, or quotation marks.
  Begin with the commit header and keep every line under 60 characters."

  let base_prompt = "Output exactly one Conventional Commit message based
  solely on the staged diff. Return only the message: no preamble, label,
  alternatives, explanation, Markdown, code fences, or quotation marks. Format
  the header as <type>(<scope>): <imperative summary>; scope is optional.
  Choose an accurate type such as feat, fix, refactor, perf, docs, test, build,
  ci, chore, or revert. Keep every line under 60 characters. Add a concise body
  only when needed to capture other meaningful changes. Mark breaking changes
  with ! and a BREAKING CHANGE: footer. Cover staged changes broadly, do not
  invent details, and never use commit history. Describe documentation and
  text-only changes briefly." 

  let prompt = $"
  ($system_prompt)
  ($base_prompt)

  Staged diff:
  ($staged)
  "

  let response = (
    &spinner --structured --quiet-cancel --msg "Summarizing" -- opencode api post /api/rpc/commit-message/generate --data ({
      input: {
        model: {
          providerID: ($model | get 0)
          id: ($model | skip 1 | str join "/")
        }
        prompt: $prompt
      }
    } | to json -r)
    | from json
  )
  if ($response.cancelled? | default false) {
    print $"(ansi red)response cancelled(ansi reset)"
    return
  }
  mut msg = ($response.stdout | from json | get output | get text | str trim)

  loop {
    print ""
    print $msg

    let answer = (input $"(ansi cyan)commit? (ansi reset)[y]es / [r]evise / [n]o: ")
    if ($answer in ["" "y" "yes"]) {
      git commit -e -m $msg
      return
    }
    if not ($answer in ["r" "revise"]) {
      return
    }
    let revision = (input $"(ansi cyan)revise how? (ansi reset)")
    if ($revision | is-empty) {
      continue
    }

    let prompt = $"($system_prompt)\n\n($base_prompt)\n\nRevise this commit message using the requested change. Preserve accurate facts from the staged diff.\n\nStaged diff:\n($staged)\n\nCurrent commit message:\n($msg)\n\nRequested change:\n($revision)"

    let response = (
      &spinner --structured --quiet-cancel --msg "Revising" -- opencode api post /api/rpc/commit-message/generate --data ({
        input: {
          model: {
            providerID: ($model | get 0)
            id: ($model | skip 1 | str join "/")
          }
          prompt: $prompt
        }
      } | to json -r)
      | from json
    )
    if ($response.cancelled? | default false) {
      print $"(ansi red)response cancelled(ansi reset)"
      return
    }
    $msg = ($response.stdout | from json | get output | get text | str trim)
  }
}
