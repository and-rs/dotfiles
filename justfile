set shell := ["nu", "-c"]

default:
  just --list

qmlfmt:
  ls -a **/*.qml -a | get name | each { try { qmlformat --single-line-empty-objects -n -w 4 -i $in }}

cppfmt:
  nix shell "nixpkgs#clang-tools" --command clang-format -i "utils/icon-validation/iconvalidator.cpp" "utils/icon-validation/iconvalidator.hpp" "utils/icon-validation/plugin.cpp"

apply:
  chezmoi --source "{{ justfile_directory() }}" apply -v --no-pager

opencode-setup: apply
  bun install --cwd dot_config/opencode --frozen-lockfile
  bun install --cwd $"($env.HOME)/.config/opencode" --frozen-lockfile

diff:
  chezmoi --source "{{ justfile_directory() }}" diff

status:
  chezmoi --source "{{ justfile_directory() }}" status

test-quickshell:
  bun test dot_config/quickshell/tests/network.test.js

opencode-check:
  bun run --cwd dot_config/opencode check

debug-capture target output_directory="":
  ./dot_config/quickshell/utils/debug-capture.sh "{{ target }}" "{{ output_directory }}"
