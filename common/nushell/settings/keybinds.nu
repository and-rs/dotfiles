def _fzf_history [] {
  let fzf_flags = [
    "--ansi"
    "--read0"
    "--with-nth=1"
    "--height=100%"
    "--delimiter=\t"
    "--scheme=history"
    "--layout=reverse"
    "--padding=1,0,0,1"
    "--prompt=History > "
    "--header=<C-d> Delete entry"
    "--bind=ctrl-d:execute-silent(_fzf_drop_history {2})+reload(_fzf_fetch_history)"
  ]
  let raw_selection = (_fzf_fetch_history | fzf ...$fzf_flags)
  if ($raw_selection | is-empty) { return }
  ($raw_selection | split row -n 2 (char tab) | get 0)
}
#
#
$env.config.keybindings = ($env.config.keybindings | append [
  {
    name: fuzzy_history
    modifier: control
    keycode: char_r
    mode: [emacs, vi_normal, vi_insert]
    event: [
      {send: ExecuteHostCommand, cmd: "do { commandline edit --insert (_fzf_history) }"}
    ]
  }
  {
    name: ctrl_f_hint_word_or_move
    modifier: control
    keycode: char_f
    mode: [emacs, vi_insert]
    event: [
      {send: HistoryHintWordComplete}
      {edit: MoveRight}
    ]
  }
  {
    name: aie_extend_command
    modifier: alt
    keycode: char_e
    mode: [emacs, vi_insert, vi_normal]
    event: {send: executehostcommand, cmd: "
      let current = (commandline)
      let new_cmd = $\"aie '($current) -- extend by: '\"
      commandline edit --replace $new_cmd
      commandline set-cursor ($new_cmd | str length | $in - 1)
      "}
  }
  {
    name: "delete_char"
    modifier: "control"
    keycode: "char_d"
    mode: ["emacs", "vi_insert", "vi_normal"]
    event: {edit: "Delete"}
  }
  {
    name: "insert_newline"
    modifier: control
    keycode: enter
    event: {edit: "insertnewline"}
    mode: [emacs, vi_insert, vi_normal]
  }
])
