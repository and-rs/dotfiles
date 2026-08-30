def --env pin-gh [] {
  let user = "and-rs"
  let docs = ($env.HOME | path join "Documents" | path expand)
  let pwd = ($env.PWD | path expand)
  let in_docs = ($pwd == $docs) or ($pwd | str starts-with $"($docs)/")

  if $in_docs {
    if ($env._GH_TOKEN_PINNED? | default "") == $user { return }
    if not (($env.GH_TOKEN? | default "") | is-empty) { return }
    if (which gh | is-empty) { return }

    let result = (gh auth token --user $user | complete)
    if $result.exit_code != 0 { return }

    let token = ($result.stdout | str trim)
    if ($token | is-empty) { return }

    $env.GH_TOKEN = $token
    $env._GH_TOKEN_PINNED = $user
  } else if ($env._GH_TOKEN_PINNED? | default "") == $user {
    hide-env -i GH_TOKEN _GH_TOKEN_PINNED
  }
}

pin-gh
