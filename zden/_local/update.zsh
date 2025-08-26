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

    echo "\n>Update complete! Restart your shell to ensure all changes are loaded."
}
