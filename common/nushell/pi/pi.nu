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

  let extensions_dir = ($env.HOME | path join ".pi" "agent" "extensions")
  if not ($extensions_dir | path exists) {
    print "no pi extensions dir"
    return
  }

  let dirs = (
    ls $extensions_dir
    | where type == dir
    | get name
    | where {|dir|
      let package_json = ($dir | path join "package.json")
      if not ($package_json | path exists) {
        false
      } else if ($name | is-empty) {
        true
      } else {
        (($dir | path basename) == $name)
      }
    }
  )

  if ($dirs | is-empty) {
    print "no matching pi extension packages"
    return
  }

  for dir in $dirs {
    print $"pi bootstrap > bun install (($dir | path basename))"
    do {
      cd $dir
      bun install
    }
  }
}

export def aip [prompt: string] {
  pi --model "github-copilot/claude-haiku-4.5:off" -p --no-session $prompt
}
