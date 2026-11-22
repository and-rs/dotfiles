const system_hook = "/run/current-system/sw/share/direnv-instant/nushell.nu"
const root_profile_hook = "/nix/var/nix/profiles/per-user/root/profile/share/direnv-instant/nushell.nu"
const default_profile_hook = "/nix/var/nix/profiles/default/share/direnv-instant/nushell.nu"
const instant_hook = if ($system_hook | path exists) {
  $system_hook
} else if ($root_profile_hook | path exists) {
  $root_profile_hook
} else if ($default_profile_hook | path exists) {
  $default_profile_hook
}
def --env normalize-direnv-path [] {
  if ($env.PATH | describe) == "string" {
    $env.PATH = do (env-conversions).path.from_string $env.PATH
  }
}

def --env unload-before-direnv-switch [] {
  let loaded = $env.DIRENV_FILE?
  if $loaded == null { return }

  # Don't leave the previous project's variables active while a new .envrc loads.
  mut dir = $env.PWD
  loop {
    let rc = ($dir | path join ".envrc")
    if $rc == $loaded { return }
    if ($rc | path exists) { break }
    let parent = ($dir | path dirname)
    if $parent == $dir or ($parent | is-empty) { return }
    $dir = $parent
  }

  let delta = (do { cd /; direnv export json } | from json | default {})
  let unset = ($delta | transpose key value | where value == null | get key)
  for key in $unset { hide-env --ignore-errors $key }
  load-env ($delta | reject ...$unset)
  hide-env --ignore-errors __DIRENV_INSTANT_ENV_FILE
  normalize-direnv-path
}

def --env stop-direnv-repaint [] {
  let id = $env.DIRENV_REPAINT_JOB?
  if $id != null {
    try { job kill $id }
    hide-env DIRENV_REPAINT_JOB
  }
}

if $instant_hook != null {
  hide-env --ignore-errors DIRENV_REPAINT_JOB
  let before_direnv = {||
    stop-direnv-repaint
    unload-before-direnv-switch
  }
  $env.config.hooks.pre_prompt ++= [$before_direnv]
  $env.config.hooks.pre_execution ++= [$before_direnv]
}
source $instant_hook

$env.config.hooks.env_change.PWD = ($env.config.hooks.env_change.PWD? | default [])
$env.config.hooks.env_change.PWD ++= [{||
  if $instant_hook == null and not (which direnv | is-empty) {
    direnv export json | from json | default {} | load-env
    normalize-direnv-path
  }
  pin-gh
}]

if $instant_hook != null {
  $env.config.hooks.pre_execution ++= [{|| normalize-direnv-path }]
}

$env.config.hooks.pre_prompt ++= [{||
  normalize-direnv-path
  let project = $env.__DIRENV_INSTANT_CURRENT_DIR?
  let rc = if $project != null { $project | path join ".envrc" }
  let loaded = $env.DIRENV_FILE?
  let env_file = $env.__DIRENV_INSTANT_ENV_FILE?
  let ready = $loaded != null and ($rc == null or $loaded == $rc)
  let socket = if not $ready and $rc != null and $env_file != null {
    $env_file | path dirname | path join "daemon.sock"
  }
  $env.POSH_DIRENV = if $ready {
    "ready"
  } else if $socket != null and ($socket | path exists) {
    "loading"
  } else {
    ""
  }

  if $env.POSH_DIRENV == "loading" and $env.POSH_CONFIG? != null {
    $env.DIRENV_REPAINT_JOB = (job spawn {
      while ($socket | path exists) { sleep 150ms }
      let completed = (try { open --raw $env_file | from json | get -o DIRENV_FILE })
      # A job can update the prompt, but the foreground hook applies the env.
      $env.POSH_DIRENV = if $completed == $rc { "ready" } else { "" }
      do $env.PROMPT_COMMAND | commandline set-prompt
    })
  }
}]
