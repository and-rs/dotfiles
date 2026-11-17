set shell := ["nu", "-c"]

default:
  just --list

install-amane:
  nix-env --install --file ./dot_config/amane/default.nix

cppfmt:
  clang-format -i ...(fd | rg -e '\.cpp' -e '\.h$' -e '\.hpp' | lines)

unmanaged:
  chezmoi --source (pwd) unmanaged -p absolute

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
