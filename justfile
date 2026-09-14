set shell := ["nu", "-c"]

default:
    just --list

qmlfmt:
  ls -a **/*.qml -a | get name | each { try { qmlformat --single-line-empty-objects -n -w 4 -i $in }}

cppfmt:
  nix shell "nixpkgs#clang-tools" --command clang-format -i "utils/icon-validation/iconvalidator.cpp" "utils/icon-validation/iconvalidator.hpp" "utils/icon-validation/plugin.cpp"

# apply & restart quickshell
AR:
    chezmoi apply -v
    try { quickshell kill }
    ~/.config/quickshell/launch.sh

apply:
    chezmoi apply -v

diff:
    chezmoi diff

status:
    chezmoi status

test-quickshell:
    bun test dot_config/quickshell/tests/network.test.js

debug-capture target output_directory="":
    ./dot_config/quickshell/utils/debug-capture.sh "{{ target }}" "{{ output_directory }}"
