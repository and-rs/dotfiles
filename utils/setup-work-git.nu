def main [
  --name: string = ""
  --email: string = ""
  --key-path: string = "~/.ssh/id_rsa"
  --force (-f)
] {
  let resolved_name = if ($name | str trim | is-empty) {
    input "Work git name: " | str trim
  } else {
    $name | str trim
  }

  let resolved_email = if ($email | str trim | is-empty) {
    input "Work git email: " | str trim
  } else {
    $email | str trim
  }

  if ($resolved_name | is-empty) {
    error make {msg: "work git name is required"}
  }

  if ($resolved_email | is-empty) {
    error make {msg: "work git email is required"}
  }

  let local_path = ($"($env.HOME)/.gitconfig-work.local")
  let expanded_key = ($key_path | path expand)

  if (($local_path | path exists) and not $force) {
    error make {msg: $"($local_path) already exists; pass --force to overwrite"}
  }

  let content = $"[core]\n    sshCommand = ssh -i ($expanded_key) -o IdentitiesOnly=yes\n\n[user]\n    name = ($resolved_name)\n    email = ($resolved_email)\n"

  $content | save --force $local_path
  ^chmod 600 $local_path

  if not ($expanded_key | path exists) {
    print $"warning: SSH key does not exist: ($expanded_key)"
  }

  print $"wrote ($local_path)"
}
