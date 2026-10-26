set shell := ["nu", "-c"]

default:
  just --list

qmlfmt:
  try { qmlformat --single-line-empty-objects -n -w 4 -i ...(fd | rg -e '\.qml$' | lines) }

qmldir:
  touch ~/.config/quickshell/.qmlls.ini

debug-capture target output_directory="":
  ./dot_config/quickshell/utils/debug-capture.sh "{{ target }}" "{{ output_directory }}"

cppfmt:
  clang-format -i ...(fd | rg -e '\.cpp' -e '\.h$' -e '\.hpp' | lines)

apply:
  chezmoi --source "{{ justfile_directory() }}" apply -v --no-pager

diff:
  chezmoi --source "{{ justfile_directory() }}" diff

status:
  chezmoi --source "{{ justfile_directory() }}" status

opencode-check:
  bun run --cwd dot_config/opencode check

opencode-setup: apply
  bun install --cwd dot_config/opencode --frozen-lockfile
  bun install --cwd $"($env.HOME)/.config/opencode" --frozen-lockfile
