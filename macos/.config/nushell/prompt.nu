# I never finished this
def dir-prompt [] {
  let command = pwd | path relative-to $env.home | path split

  try {
    if (pwd | path relative-to $env.home | is-empty) {
      "~"
    } else {
      if ($command | length) < 1 {
        $command | insert 0 "~"  | str join "/"
      } else if ($command | length) <= 2 {
        $command | insert 0 "~"  | str join "/"
      } else {
        $command | last 2 | insert 0 "." | str join "/"
      }
    }
  } catch {
    pwd
  }
}

def wt-unmodified [] {
  let stat = gstat | get wt_modified
  if $stat > 0 {
    $"(ansi g)!($stat)"
  }
}

def git-status [] {
  if (gstat | get idx_added_staged) == -1 {
    ""
  } else {
    $"(ansi dgr)on (ansi c)(gstat | get branch) (wt-unmodified)"
  }
}

let start_character_top = $"(ansi dgr)╭─"
let start_character_bot = $"(ansi dgr)╰─"

$env.PROMPT_COMMAND = { || $"($start_character_top) (ansi c)(dir-prompt) (git-status)\n($start_character_bot) " }
$env.PROMPT_INDICATOR = $"(ansi c)$ "
$env.PROMPT_COMMAND_RIGHT = ""
$env.TRANSIENT_PROMPT_COMMAND = ""
