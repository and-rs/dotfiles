#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd -- "$project_dir"

if [[ ${1:-} != --watch ]]; then
    export AMANE_DEV_SCRIPT
    AMANE_DEV_SCRIPT="$(realpath -- "${BASH_SOURCE[0]}")"
    # Expand the exported script path inside nix-shell.
    # shellcheck disable=SC2016
    exec nix-shell "$project_dir/shell.nix" \
        --run 'exec bash "$AMANE_DEV_SCRIPT" --watch'
fi

registration="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR must be set}/amane_dev"
exec 9>"$registration.lock"
if ! flock --nonblock 9; then
    echo "Amane development watcher is already running." >&2
    exit 1
fi
ln -sfn -- "$CARGO_TARGET_DIR/release/amane_shell" "$registration"
trap 'rm -f -- "$registration"' EXIT
trap 'kill "$watcher" 2>/dev/null || true; wait "$watcher" || true; exit 130' INT
trap 'kill "$watcher" 2>/dev/null || true; wait "$watcher" || true; exit 143' TERM

# Use optimized rendering in the watcher so UI testing reflects normal frame times.
watchexec --restart --watch src --watch Cargo.toml --watch Cargo.lock -- cargo run --release --locked &
watcher=$!
wait "$watcher"
