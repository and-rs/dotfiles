#!/usr/bin/env bash

set -eu

target=${1:?"Usage: debug-capture.sh <target> [output-directory]"}
requested_output=${2:-}
capture_root=${QS_DEBUG_CAPTURE_DIR:-/tmp/quickshell-debug}
retain=${QS_DEBUG_CAPTURE_RETAIN:-10}
generated_output=false
capture_started=false

if [[ ! $target =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  printf '%s\n' "Invalid capture target: $target" >&2
  exit 2
fi
if [[ ! $retain =~ ^[1-9][0-9]*$ ]]; then
  printf '%s\n' "QS_DEBUG_CAPTURE_RETAIN must be a positive integer" >&2
  exit 2
fi

cleanup_captures() {
  local directories=() index
  [[ -d $capture_root ]] || return
  mapfile -t directories < <(for directory in "$capture_root"/*/; do
    [[ -d $directory ]] && printf '%s\t%s\n' "$(stat -c %Y "$directory")" "$directory"
  done | sort -rn | cut -f2-)
  for ((index = retain; index < ${#directories[@]}; index++)); do
    rm -rf -- "${directories[index]}"
  done
}

if [[ -n $requested_output ]]; then
  output_directory=$requested_output
  mkdir -p "$output_directory"
else
  mkdir -p "$capture_root"
  cleanup_captures
  output_directory=$(mktemp -d "$capture_root/$target-XXXXXX")
  generated_output=true
fi

remove_generated_output() {
  if [[ $generated_output == true ]]; then
    rm -rf -- "$output_directory"
  fi
}
close_capture() {
  if [[ $capture_started == true ]]; then
    quickshell ipc call debug close >/dev/null 2>&1 || true
    capture_started=false
  fi
}
cleanup_on_error() {
  close_capture
  remove_generated_output
}

ipc_output=$(quickshell ipc call debug capture "$target" "$output_directory" 2>&1) || {
  printf '%s\n' "$ipc_output" >&2
  printf '%s\n' "Debug capture is unavailable. Set Config.debug.enabled to true and reload Quickshell." >&2
  remove_generated_output
  exit 1
}
if [[ $ipc_output == *"Target not found"* ]]; then
  printf '%s\n' "$ipc_output" >&2
  printf '%s\n' "Debug capture is unavailable. Set Config.debug.enabled to true and reload Quickshell." >&2
  remove_generated_output
  exit 1
fi
capture_started=true
trap cleanup_on_error ERR

for _ in $(seq 1 50); do
  [[ -s "$output_directory/$target.png" ]] && break
  sleep 0.1
done
if [[ ! -s "$output_directory/$target.png" ]]; then
  printf '%s\n' "Timed out waiting for $target.png" >&2
  close_capture
  remove_generated_output
  exit 1
fi

grim "$output_directory/compositor.png"
quickshell log -t 40 > "$output_directory/runtime.log"
close_capture
cleanup_captures
printf '%s\n' "Debug captures saved to $output_directory"
