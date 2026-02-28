export use git_add.nu *
export use git_diff.nu  *
export use git_diff_staged.nu *
export use git_log.nu *
export use git_restore_staged.nu *

export def _forgit_check_repo [] {
  if (git rev-parse --is-inside-work-tree | complete | get exit_code) != 0 {
    error make {msg: "Not in a git repository"}
  }
}

export-env {
  $env.FORGIT_NU_DEFAULT_FLAGS = [
    "--padding=1,0,0,1"
    "--ansi"
    "--cycle"
    "--multi"
    "--preview-window=right,60%"
    "--bind=ctrl-d:half-page-down,ctrl-u:half-page-up"
    "--bind=ctrl-alt-d:preview-page-down,ctrl-alt-u:preview-page-up"
  ]
}
