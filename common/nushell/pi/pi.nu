def _pi_tools [] {
  "bash,exa-search,web-fetch,hashline-read,hashline-edit,file-create,code-overview,code-search,code-files"
}

def ai [...args: string] {
  if ($args | length) == 0 {
    if (which pi | is-empty) {
      print "pi not installed. run: ai install"
      return
    }
    ^pi --tools (_pi_tools)
    return
  }

  ^pi --tools (_pi_tools) ...$args
}

def "ai install" [...args: string] {
  if (which npm | is-empty) {
    print "npm not found"
    return
  }

  if ($args | is-empty) {
    print "ai install > installing pi"
    ^npm install -g @earendil-works/pi-coding-agent
    return
  }

  if (which pi | is-empty) {
    print "ai install > installing pi"
    ^npm install -g @earendil-works/pi-coding-agent
  }

  ^pi install ...$args
}

def "ai bootstrap" [name?: string] {
  if (which npm | is-empty) {
    print "npm not found"
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
    print $"pi bootstrap > npm install (($dir | path basename))"
    do {
      cd $dir
      ^npm install
    }
  }
}

def aip [prompt: string] {
  pi --tools (_pi_tools) --model "github-copilot/claude-haiku-4.5:off" -p --no-session $prompt
}
