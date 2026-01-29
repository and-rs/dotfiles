#zmodload zsh/zprof

export PATH="$HOME/Vault/personal/yazi/target/release:$PATH"
export PATH="/usr/bin:$PATH"
export PATH="$HOME/bins:$PATH"
# export PATH="$PATH:$HOME/.cargo/bin"

typeset -U path PATH
export DOTS=$HOME/Vault/personal/dotfiles

# If not in tmux, start tmux.
if [[ -z ${TMUX+X}${ZSH_SCRIPT+X}${ZSH_EXECUTION_STRING+X} ]]; then
    exec tmux -u new -s init -A -D
fi

function zcompile-many() {
    local f
    for f; do zcompile -R -- "$f".zwc "$f"; done
}

ZDEN=$HOME/.zden

# Clone and compile to wordcode missing plugins.
if [[ ! -e $ZDEN/powerlevel10k ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZDEN/powerlevel10k"
    make -C "$ZDEN/powerlevel10k" pkg
fi
if [[ ! -e $ZDEN/fzf-tab ]]; then
    git clone --depth=1 https://github.com/Aloxaf/fzf-tab "$ZDEN/fzf-tab"
    zcompile-many "$ZDEN/fzf-tab/"*.zsh
fi
if [[ ! -e $ZDEN/zsh-syntax-highlighting ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZDEN/zsh-syntax-highlighting"
    zcompile-many "$ZDEN/zsh-syntax-highlighting/{zsh-syntax-highlighting.zsh,highlighters/*/*.zsh}"
fi
if [[ ! -e $ZDEN/zsh-autosuggestions ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$ZDEN/zsh-autosuggestions"
    zcompile-many "$ZDEN/zsh-autosuggestions/{zsh-autosuggestions.zsh,src/**/*.zsh}"
fi
if [[ ! -e $ZDEN/forgit ]]; then
    git clone --depth=1 https://github.com/wfxr/forgit.git "$ZDEN/forgit"
    zcompile-many "$ZDEN/forgit/forgit.plugin.zsh"
fi

# Enable Powerlevel10k instant prompt. This is after the plugin verfs.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Loading p10k theme before anything
source "$ZDEN/powerlevel10k/powerlevel10k.zsh-theme"
[[ ! -f $ZDEN/p10k.zsh ]] || source "$ZDEN/p10k.zsh"

autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
    compinit -d ~/.zcompdump
else
    compinit -C -d ~/.zcompdump
fi
[[ ~/.zcompdump.zwc -nt ~/.zcompdump ]] || zcompile-many ~/.zcompdump

# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

# order matters
source $ZDEN/_local/transient.zsh
source $ZDEN/_local/options.zsh
source $ZDEN/_local/aliases.zsh
source $ZDEN/_local/dirtree.zsh
source $ZDEN/_local/filepath.zsh
source $ZDEN/_local/forgit.zsh
source $ZDEN/_local/fzf.zsh
source $ZDEN/_local/git.zsh
source $ZDEN/_local/qsv.zsh
source $ZDEN/_local/rclone.zsh
source $ZDEN/_local/update.zsh

# Forgit patch
typeset -f zden-patch-forgit >/dev/null && zden-patch-forgit

# Load plugins
source "$ZDEN/fzf-tab/fzf-tab.plugin.zsh"
source "$ZDEN/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$ZDEN/forgit/forgit.plugin.zsh" && PATH="$PATH:$FORGIT_INSTALL_DIR/bin"
source "$ZDEN/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Caching the output for eval commands
zoxide_cache_file="$ZDEN/_zoxide_init.zsh"
if [[ ! -r "$zoxide_cache_file" ]] || [[ "$(command -v zoxide)" -nt "$zoxide_cache_file" ]]; then
    zoxide init zsh > "$zoxide_cache_file"
fi
source "$zoxide_cache_file"

direnv_cache_file="$ZDEN/_direnv_hook.zsh"
if [[ ! -r "$direnv_cache_file" ]] || [[ "$(command -v direnv)" -nt "$direnv_cache_file" ]]; then
    direnv hook zsh > "$direnv_cache_file"
fi
source "$direnv_cache_file"

uv_cache_file="$ZDEN/_uv_completion.zsh"
if [[ ! -r "$uv_cache_file" ]] || [[ "$(command -v uv)" -nt "$uv_cache_file" ]]; then
    uv generate-shell-completion zsh > "$uv_cache_file"
fi
source "$uv_cache_file"
