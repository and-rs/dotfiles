def --wrapped nvim [...args] {
  let editor = ($env.config.buffer_editor? | default $env.EDITOR)
  if ($editor | describe) == "list<string>" {
    run-external ($editor | first) ...($editor | skip 1) ...$args
  } else {
    run-external $editor ...$args
  }
}

def asus [--quiet (-q) --performance (-p)] {
  if not $quiet and not $performance {
    print "Add -q or -p"
    return 1
  }
  if $quiet {
    asusctl profile set Quiet
    asusctl armoury set nv_temp_target 75
    asusctl armoury set ppt_pl2_sppt 25
    asusctl armoury set ppt_pl1_spl 25
  } else if $performance {
    asusctl profile set Performance
    asusctl armoury set nv_temp_target 87
    asusctl armoury set ppt_pl2_sppt 40
    asusctl armoury set ppt_pl1_spl 40
  }
  asusctl armoury list
  asusctl profile get
}

def wipe-font-cache [] { rm -rf ~/.cache/fontconfig; fc-cache -r -v }
alias dark-mode-gnome = dconf write /org/gnome/desktop/interface/color-scheme '"prefer-dark"'
alias light-mode-gnome = dconf write /org/gnome/desktop/interface/color-scheme '"prefer-light"'

def sync-clock [] {
  let http_date = (
    curl -sI https://www.google.com
    | lines
    | where $it =~ '(?i)^date:'
    | first
    | str replace -r '(?i)^date:\s*' ''
    | str trim
  )
  let offset = (
    (date now | into int) - ($http_date | into datetime | into int)
    | math abs
  )
  if $offset > 15_000_000_000 {
    print "Clock differs from HTTPS time by more than 15 seconds; synchronizing."
    sudo /usr/bin/date --utc --set $http_date
  }
}

def colors [] { 0..15 | each {|c| $"(ansi --escape $'48;5;($c)m')  (ansi reset)" } }
alias link-nvim = ln -s ~/Vault/personal/nvim ~/.config
alias yz = yazi
alias l = ls -a
alias md = table -t markdown
alias c = clear --keep-scrollback
alias ld = eza -lha --no-permissions --no-user --no-time
alias lt = eza -lhaT --no-permissions --no-user --no-time --git-ignore
alias caffeine = systemd-inhibit --what=idle:sleep --why="no-sleep" sleep infinity
alias ff = fastfetch --logo-color-1 cyan --file $"($env.DOTS)/utils/ascii/spider2.txt"
alias ffn = fastfetch --logo-color-1 red --file $"($env.DOTS)/utils/ascii/spider2.txt" --config neofetch

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

# Docker + VM Start
def win-start [] {
  let is_running = (
    docker inspect -f '{{.State.Running}}' WinBoat | complete | get stdout | str trim
  )
  if $is_running != "true" {
    docker start WinBoat
    sleep 10sec
  }
  xfreerdp /v:127.0.0.1:47300 /u:andrs /p:jersey +clipboard /cert:ignore -compression +dynamic-resolution /scale:180
}

# VSCode Darwin check
def code [...args] {
  if (sys host | get name) != "Darwin" { return 1 }
  with-env {VSCODE_CWD: (pwd)} {
    ^open -n -b "com.microsoft.VSCode" --args ...$args
  }
}
