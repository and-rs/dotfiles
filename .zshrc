# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

# Periodic auto-update on Zsh startup: 'ask' or 'no'.
zstyle ':z4h:' auto-update      'ask'
# Ask whether to auto-update this often; has no effect if auto-update is 'no'.
zstyle ':z4h:' auto-update-days '28'

# Start tmux if not already in tmux.
zstyle ':z4h:' start-tmux command tmux -u new -s init -A -D

# Whether to move prompt to the bottom when zsh starts and on Ctrl+L.
zstyle ':z4h:' prompt-at-bottom 'no'

# Mark up shell's output with semantic information.
zstyle ':z4h:' term-shell-integration 'yes'

# Right-arrow key accepts one character ('partial-accept') from
# command autosuggestions or the whole thing ('accept')?
zstyle ':z4h:autosuggestions' forward-char 'partial-accept'

# Recursively traverse directories when TAB-completing files.
zstyle ':z4h:fzf-complete' recurse-dirs 'no'

# Enable direnv to automatically source .envrc files.
zstyle ':z4h:direnv' enable 'yes'

# Show "loading" and "unloading" notifications from direnv.
zstyle ':z4h:direnv:success' notify 'yes'

# Enable ('yes') or disable ('no') automatic teleportation of z4h over
# SSH when connecting to these hosts.
# zstyle ':z4h:ssh:example-hostname1'   enable 'yes'
# zstyle ':z4h:ssh:*.example-hostname2' enable 'no'
# The default value if none of the overrides above match the hostname.
zstyle ':z4h:ssh:*' enable 'no'

# Send these files over to the remote host when connecting over SSH to the
# enabled hosts.
zstyle ':z4h:ssh:*' send-extra-files '~/.nanorc' '~/.env.zsh'

# Init z4h
z4h init || return

# Export environment variables.
export GPG_TTY=$TTY

# Source additional local files if they exist.
z4h source ~/.env.zsh

# Autoload functions.
autoload -Uz zmv

# Define functions and completions.
function md() { [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" }
compdef _directories md

# Define named directories: ~w <=> Windows home directory on WSL.
[[ -z $z4h_win_home ]] || hash -d w=$z4h_win_home

# Define Editor
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
  --color=fg:8,fg+:4,bg:-1,bg+:-1
  --color=hl:4,hl+:4,info:4,marker:4
  --color=prompt:4,spinner:4,pointer:4,header:4
  --color=border:4,query:7
  --marker=":" --pointer="»"'

export MANPAGER='nvim +Man!'

UTILS="$HOME/vault/personal/dotfiles/utils"
SCRIPTS="$HOME/vault/personal/dotfiles/scripts"
BOX="$HOME/vault/personal"

# Extend PATH.
path=(~/bin $path $BOX/zig)

# Define aliases.
alias l="eza -liha"
alias lt="eza -lihaT --git-ignore"
alias c="clear -x"
alias nv="nvim"
alias nd="neovide --fork --title-hidden --frame=transparent"
alias sw="stow -t $HOME"
alias f=". $SCRIPTS/fzf/search.sh"
alias s=". $SCRIPTS/fzf/vault.sh"
alias config-zsh="$EDITOR ~/.zshrc"
alias config-tmux="$EDITOR ~/.tmux.conf"

alias u-nixos="sudo nixos-rebuild switch --flake '$BOX/nixos#default'"
alias u-darwin="nix --extra-experimental-features 'nix-command flakes' run nix-darwin -- switch --flake $BOX/nix-darwin"

alias ff="fastfetch --logo-color-1 red --file $UTILS/ascii/spider2.txt --config paleofetch"
# alias ghostty='/Applications/Ghostty.app/Contents/MacOS/ghostty'

alias gac="git add . && git commit -m"
alias ga="git add"
alias gp="git push"
alias gc="git commit"
alias gs="git status"

# History options
HISTSIZE=7000
SAVEHIST=$HISTSIZE
HISTDUP=erase

setopt hist_ignore_all_dups
setopt hist_find_no_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt appendhistory
setopt sharehistory

# Set shell options: http://zsh.sourceforge.net/Doc/Release/Options.html.
setopt glob_dots     # no special treatment for file names with a leading dot
setopt no_auto_menu  # require an extra TAB press to open the completion menu

eval "$(direnv hook zsh)"
