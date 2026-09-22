set shell := ["nu", "-c"]

default:
    just --list

qmlfmt:
  ls -a **/*.qml -a | get name | each { try { qmlformat --single-line-empty-objects -n -w 4 -i $in }}

cppfmt:
  nix shell "nixpkgs#clang-tools" --command clang-format -i "utils/icon-validation/iconvalidator.cpp" "utils/icon-validation/iconvalidator.hpp" "utils/icon-validation/plugin.cpp"

apply:
    chezmoi apply -v --no-pager

diff:
    chezmoi diff

status:
    chezmoi status

test-quickshell:
    bun test dot_config/quickshell/tests/network.test.js

pi-check:
    bun run --cwd dot_pi/agent/extensions check

debug-capture target output_directory="":
    ./dot_config/quickshell/utils/debug-capture.sh "{{ target }}" "{{ output_directory }}"
