sync-icloud() {
    # use this command to setup icloud auth first
    # rclone --user-agent="helo" config

    if [[ $(uname -s) != "Linux" ]]; then
        echo "This function only works on Linux systems."
        return 1
    fi

    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: sync-icloud [extra rclone bisync args]"
        echo "Example: sync-icloud --force --resync"
        return 0
    fi

    local src="icloud:important"
    local dst="$HOME/icloud-drive"

    notify-send "iCloud Sync" "Starting bisync for 'important' folder..." || true

    rclone bisync \
        "$src" "$dst" \
        --compare size,modtime,checksum \
        --create-empty-src-dirs \
        --conflict-resolve newer \
        --metadata \
        --progress \
        --verbose \
        "$@"

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        notify-send "iCloud Sync" "Bisync completed successfully." || true
    else
        notify-send "iCloud Sync Error" "Bisync failed with exit code $exit_code. Check logs for details." || true
        return $exit_code
    fi
}
