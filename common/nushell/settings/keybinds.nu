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
    "--bind=ctrl-d:execute-silent(&fzf_drop_history {2})+reload(&fzf_fetch_history)"
  ]
  let raw_selection = &fzf_fetch_history | fzf ...$fzf_flags
  if ($raw_selection | is-empty) { return }
  ($raw_selection | split row -n 2 (char tab) | get 0)
}

$env.config.menus = (
  $env.config.menus | append [{
    name: file_menu
    only_buffer_difference: false
    input_mode: cursor_prefix
    marker: "| "
    type: {
      layout: columnar
      columns: 4
      col_padding: 2
      tab_traversal: vertical
    }
    style: {
      text: green
      selected_text: green_reverse
      description_text: yellow
      match_text: {attr: u}
      selected_match_text: {attr: ur}
    }
    source: {|buffer, position|
      let contextual = (
        $buffer
        | commandline complete --detailed
        | where kind in [file directory]
      )

      if ($contextual | is-not-empty) {
        $contextual
      } else {
        let path = ($buffer | str replace -r '^.*\s' '')
        let path_start = (($buffer | str length) - ($path | str length))

        $path
        | commandline complete --detailed --type path
        | each {|completion|
          $completion
          | update span {
            {
              start: ($in.start + $path_start)
              end: ($in.end + $path_start)
            }
          }
        }
      }
    }
  }]
)

$env.config.keybindings = (
  $env.config.keybindings | append [
    {
      name: fuzzy_history
      modifier: control
      keycode: char_r
      mode: [emacs vi_normal vi_insert]
      event: [
        {send: ExecuteHostCommand cmd: "do { commandline edit --insert (_fzf_history) }"}
      ]
    }
    {
      name: ctrl_f_hint_word_or_move
      modifier: control
      keycode: char_f
      mode: [emacs vi_insert]
      event: {
        until: [
          {send: HistoryHintWordComplete}
          {send: MenuRight}
          {send: Right}
        ]
      }
    }
    {
      name: file_menu
      modifier: control
      keycode: char_g
      mode: [emacs vi_insert]
      event: {
        until: [
          {send: menu name: file_menu}
          {send: MenuNext}
        ]
      }
    }
    {
      name: aie_extend_command
      modifier: alt
      keycode: char_e
      mode: [emacs vi_insert vi_normal]
      event: {
        send: executehostcommand
        cmd: "
         let current = (commandline)
         let new_cmd = $\"aie '($current) -- extend by: '\"
         commandline edit --replace $new_cmd
         commandline set-cursor ($new_cmd | str length | $in - 1)
         "
      }
    }
    {
      name: "delete_char"
      modifier: "control"
      keycode: "char_d"
      mode: ["emacs" "vi_insert" "vi_normal"]
      event: {edit: "Delete"}
    }
  ]
)
