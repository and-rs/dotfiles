set shell := ["nu", "-c"]

default:
    just --list

qmlfmt:
  fd | lines | where $it =~ `\.qml` | each {|i| qmlformat -n -i -w 2 $i }

cppfmt:
  nix shell "nixpkgs#clang-tools" --command clang-format -i "utils/icon-validation/iconvalidator.cpp" "utils/icon-validation/iconvalidator.hpp" "utils/icon-validation/plugin.cpp"

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
