export alias "ai" = pi

export def "ai install" [...args: string] {
  if (which bun | is-empty) {
    print "bun not found"
    return
  }

  if ($args | is-empty) {
    print "ai install > installing pi"
    bun install --global @earendil-works/pi-coding-agent
    return
  }

  if (which pi | is-empty) {
    print "ai install > installing pi"
    bun install --global @earendil-works/pi-coding-agent
  }

  pi install ...$args
}

export def "ai bootstrap" [name?: string] {
  if (which bun | is-empty) {
    print "bun not found"
    return
  }

  let target = ($name | default "agent")
  if $target != "agent" {
    print $"unknown bootstrap target: ($target)"
    print "use: ai bootstrap"
    return
  }

  let agent_dir = ($env.HOME | path join ".pi" "agent")
  let extensions_dir = ($agent_dir | path join "extensions")
  let extensions_package = ($extensions_dir | path join "package.json")
  if not ($extensions_package | path exists) {
    print "no pi agent extensions package"
    return
  }

  print "pi bootstrap > bun install agent extensions"
  do {
    cd $extensions_dir
    bun install
  }
}

export def aip [prompt: string] {
  let model = (_ai_summarize_model)
  pi --model $model -p --no-session $prompt
}
