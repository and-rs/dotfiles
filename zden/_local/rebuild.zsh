function zden-rebuild() {
    echo "=> Removing all cloned plugin repositories..."
    rm -rf "$ZDEN"/powerlevel10k
    rm -rf "$ZDEN"/fzf-tab
    rm -rf "$ZDEN"/zsh-syntax-highlighting
    rm -rf "$ZDEN"/zsh-autosuggestions
    rm -rf "$ZDEN"/forgit

    echo "=> Removing all cached files..."
    rm -f "$ZDEN"/_zoxide_init.zsh
    rm -f "$ZDEN"/_direnv_hook.zsh
    rm -f "$ZDEN"/_uv_completion.zsh
    rm -f ~/.zcompdump*

    echo "\nRebuild complete. Restart the shell to re-download and chache again"
}
