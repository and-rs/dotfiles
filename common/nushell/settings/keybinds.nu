$env.config.keybindings = ($env.config.keybindings | append [
   # Alt+E: extend command with aichat
   {
      name: aie_extend_command
      modifier: alt
      keycode: char_e
      mode: [emacs, vi_insert, vi_normal]
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
   # Ctrl+D: sends delete
   {
      name: "delete_char"
      modifier: "control"
      keycode: "char_d"
      mode: ["emacs" "vi_insert" "vi_normal"]
      event: { edit: "Delete" }
   }
   # Shift+Enter: adds new line
   {
      name: "insert_newline"
      modifier: control
      keycode: enter
      event: { edit: "insertnewline" }
      mode: [emacs vi_insert vi_normal]
   }
])
