#!/usr/bin/env bash
set -euo pipefail

# this is just test and I should rewrite this in nu

xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
xdg_data_dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

dirs=("$xdg_data_home")
while IFS= read -r dir; do
    dirs+=("$dir")
done < <(printf '%s\n' "$xdg_data_dirs" | tr ':' '\n')

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

for root in "${dirs[@]}"; do
    appdir="$root/applications"
    [[ -d "$appdir" ]] || continue

    while IFS= read -r -d '' file; do
        awk -v file="$file" '
      BEGIN {
        name = ""
        nodisplay = "false"
        hidden = "false"
        in_entry = 0
      }
      /^\[Desktop Entry\]/ {
        in_entry = 1
        next
      }
      /^\[/ && $0 != "[Desktop Entry]" {
        in_entry = 0
      }
      !in_entry {
        next
      }
      /^Name=/ && name == "" {
        name = substr($0, 6)
      }
      /^NoDisplay=/ {
        nodisplay = substr($0, 11)
      }
      /^Hidden=/ {
        hidden = substr($0, 8)
      }
      END {
        if (name != "" && nodisplay != "true" && hidden != "true") {
          n = split(file, parts, "/")
          id = parts[n]
          sub(/\.desktop$/, "", id)
          printf "%s\t%s\t%s\n", name, id, file
        }
      }
    ' "$file"
    done < <(find -L "$appdir" -maxdepth 1 -name '*.desktop' -print0)
done | sort -u >"$tmp"

selection="$(
  fzf \
    --layout=reverse \
    --height=100% \
    --border \
    --prompt='apps > ' \
    --delimiter=$'\t' \
    --with-nth=1,2 \
    <"$tmp"
)"

[[ -n "${selection:-}" ]]

IFS=$'\t' read -r _name _id file <<<"$selection"

command -v dex >/dev/null 2>&1

setsid -f dex "$file" >/dev/null 2>&1 </dev/null
exit 0
