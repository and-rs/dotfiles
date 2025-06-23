#!/usr/bin/env zsh

export FORGIT_FZF_DEFAULT_OPTS="
  --exact --cycle --reverse --preview-border='line' --no-scrollbar
  --height '100%' --padding '1,1,0,1'"

export FORGIT_DIFF_FZF_OPTS="
  --prompt='git diff > '
  "

function zden-patch-forgit() {
  local forgit_plugin_file="$ZSH_DEN/forgit/forgit.plugin.zsh"

  [[ -e "$forgit_plugin_file" ]] || return 0

  local code
  code=$(<"$forgit_plugin_file") || {
    print -f "zsh: warning: Failed to read %s for Forgit patch.\n" "$forgit_plugin_file" >&2
    return 1
  }

  local orig_patch_target="
    set | awk -F '=' '{ print \$1 }' | grep FORGIT_ | while read -r var; do
        if ! export | grep -q \"\\(^\$var=\\|^export \$var=\\)\"; then
  "

  local sub_patch_target='
    for var in "${(@)parameters[(I)FORGIT_*]}"; do
        if [[ ${parameters[$var]} != *export* ]]; then
  '

  if [[ "$code" == *"$orig_patch_target"* ]]; then
    print -r -- ${code/$orig_patch_target/$sub_patch_target} > "$forgit_plugin_file" || {
      print -f "zsh: warning: Failed to apply Forgit patch to %s.\n" "$forgit_plugin_file" >&2
      return 1
    }
  else
  fi
}
