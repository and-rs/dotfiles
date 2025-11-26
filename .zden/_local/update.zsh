function zden-update() {
    echo "> Checking for updates in all plugin repositories..."

    for plugin_dir in "$ZDEN"/*; do
        if [[ -d "$plugin_dir/.git" ]]; then
            (
                cd "$plugin_dir" && \
                    echo "--> Updating $(basename "$plugin_dir")..." && \
                    git pull --rebase --autostash
            )
        fi
    done

    echo "\n> Re-compiling plugins..."

    # Re-run the original compilation steps to update the .zwc files.
    zcompile-many "$ZDEN/fzf-tab/"*.zsh
    zcompile-many "$ZDEN/forgit/forgit.plugin.zsh"
    zcompile-many "$ZDEN/zsh-syntax-highlighting/{zsh-syntax-highlighting.zsh,highlighters/*/*.zsh}"
    zcompile-many "$ZDEN/zsh-autosuggestions/{zsh-autosuggestions.zsh,src/**/*.zsh}"
    make -C "$ZDEN/powerlevel10k" pkg

    # Removing previous chaches to refresh
    rm "$ZDEN/_zoxide_init.zsh"
    rm "$ZDEN/_direnv_hook.zsh"
    rm "$ZDEN/_uv_completion.zsh"

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

    echo "\n>Update complete! Restart your shell to ensure all changes are loaded."
}
