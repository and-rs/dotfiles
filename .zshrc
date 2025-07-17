# If not in tmux, start tmux.
if [[ -z ${TMUX+X}${ZSH_SCRIPT+X}${ZSH_EXECUTION_STRING+X} ]]; then
    exec tmux -u new -s init -A -D
fi

function zcompile-many() {
    local f
    for f; do zcompile -R -- "$f".zwc "$f"; done
}

ZSH_DEN=$HOME/zsh-den

# Clone and compile to wordcode missing plugins.
if [[ ! -e $ZSH_DEN/powerlevel10k ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_DEN/powerlevel10k"
    make -C "$ZSH_DEN/powerlevel10k" pkg
fi
if [[ ! -e $ZSH_DEN/fzf-tab ]]; then
    git clone --depth=1 https://github.com/Aloxaf/fzf-tab "$ZSH_DEN/fzf-tab"
fi
if [[ ! -e $ZSH_DEN/zsh-syntax-highlighting ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_DEN/zsh-syntax-highlighting"
    zcompile-many "$ZSH_DEN/zsh-syntax-highlighting/{zsh-syntax-highlighting.zsh,highlighters/*/*.zsh}"
fi
if [[ ! -e $ZSH_DEN/zsh-autosuggestions ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_DEN/zsh-autosuggestions"
    zcompile-many "$ZSH_DEN/zsh-autosuggestions/{zsh-autosuggestions.zsh,src/**/*.zsh}"
fi

# sourcing forgit utils in case patching is needed
source "$ZSH_DEN/forgit.zsh"
if [[ ! -e $ZSH_DEN/forgit ]]; then
    git clone --depth=1 https://github.com/wfxr/forgit.git "$ZSH_DEN/forgit"
    zden-patch-forgit
fi

# Enable Powerlevel10k instant prompt. This is after the plugin verfs.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Enable the "new" completion system (compsys).
autoload -Uz compinit && compinit
[[ ~/.zcompdump.zwc -nt ~/.zcompdump ]] || zcompile-many ~/.zcompdump
unfunction zcompile-many

# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

source "$ZSH_DEN/powerlevel10k/powerlevel10k.zsh-theme"
[[ ! -f $ZSH_DEN/p10k.zsh ]] || source "$ZSH_DEN/p10k.zsh"

# zden setup
source "$ZSH_DEN/aliases.zsh"
source "$ZSH_DEN/opts.zsh"
source "$ZSH_DEN/git.zsh"
source "$ZSH_DEN/fzf.zsh"

# Load plugins
source "$ZSH_DEN/fzf-tab/fzf-tab.plugin.zsh"
source "$ZSH_DEN/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$ZSH_DEN/forgit/forgit.plugin.zsh" && PATH="$PATH:$FORGIT_INSTALL_DIR/bin"
source "$ZSH_DEN/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"
