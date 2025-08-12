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

let start_character_top = $"(ansi dgr)╭─"
let start_character_bot = $"(ansi dgr)╰─"

$env.PROMPT_COMMAND = { || $"($start_character_top) (ansi p)nu (ansi c)(dir-prompt) \n($start_character_bot) " }
$env.PROMPT_INDICATOR = $"(ansi c)$ "
$env.PROMPT_COMMAND_RIGHT = ""
$env.TRANSIENT_PROMPT_COMMAND = ""
