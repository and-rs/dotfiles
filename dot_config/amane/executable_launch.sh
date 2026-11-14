#!/usr/bin/env bash
set -euo pipefail

export AMANE_PROJECT_DIR
AMANE_PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

exec nix-shell "$AMANE_PROJECT_DIR/shell.nix" \
    --run 'exec cargo run --release --locked --manifest-path "$AMANE_PROJECT_DIR/Cargo.toml"'
