alias &dark-mode-gnome = dconf write /org/gnome/desktop/interface/color-scheme '"prefer-dark"'
alias &light-mode-gnome = dconf write /org/gnome/desktop/interface/color-scheme '"prefer-light"'
alias &loc = tokei -r code -C

alias g = git
alias gc = git commit
alias gl = git log --oneline -n 10
alias gs = git status

alias yz = yazi
alias nv = neovide --neovim-bin $"(echo $env.EDITOR)" --chdir .

alias md = table -t markdown
alias c = clear --keep-scrollback

def ls [--sortable (-s)] {
  let size_width = (%ls --all | get size | each { into string | str length } | math max)
  %ls --all | sort-by type | each {|line|
    return {
      name: $line.name
      size: (
        if $line.type == "dir" {
          $"(ansi blue)dir" | fill --alignment right --width $size_width
        } else { $line.size }
      )
      modified: $line.modified
    }
  } | if (not $sortable) { $in | table -i false } else { $in }
}

alias ld = eza -lha --no-permissions --no-user --no-time
alias lt = eza -lhaT --no-permissions --no-user --no-time --git-ignore

alias ff = fastfetch --logo-color-1 cyan --file $"($env.DOTS)/utils/ascii/spider2.txt"
alias ffn = fastfetch --logo-color-1 red --file $"($env.DOTS)/utils/ascii/spider2.txt" --config neofetch

# --- KEEP THESE FUNCTIONS DEFINED HERE ---

export def --wrapped vi [...args] {
  let editor = ($env.config.buffer_editor? | default $env.EDITOR)
  if ($editor | describe) == "list<string>" {
    run-external ($editor | first) ...($editor | skip 1) ...$args
  } else {
    run-external $editor ...$args
  }
}

# Load opam env vars to the path (of course it isn't eval) (with oxcaml handling)
def --env "opam eval" [switch?: string] {
  if ($switch | is-empty) { $env.OPAMSWITCH = "5.2.0+ox" }
  opam env --shell=powershell (if ($switch | is-empty) { "--switch=5.2.0+ox" })
  | lines
  | where ($it | str starts-with '$env:')
  | parse "$env:{key} = '{value}'"
  | transpose -rd
  | update PATH {|r| $r.PATH | split row (char esep) }
  | load-env
}

# Interactive Directory Picker
def --env f [] {
  let excludes = [
    node_module
    .git
    .cache
    .npm
    .mozilla
    .meteor
    .nv
  ]
  let cmd_args = $excludes | each {|it| ["--exclude" $it] } | flatten
  let selected_dir = (
    fd --type d --hidden ...$cmd_args
    | fzf --prompt="choose directory > " --reverse --info="right" --padding="1,0,0,1"
    | str trim
  )
  if ($selected_dir | is-not-empty) { cd $selected_dir } else { print "No directory selected." }
}
