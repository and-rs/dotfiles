#!/usr/bin/env bash

set -eu

output_directory=${1:-"/tmp/quickshell-network-debug/$(date +%Y%m%d-%H%M%S)"}
mkdir -p "$output_directory"

ipc_output=$(quickshell ipc call network-debug capture "$output_directory" 2>&1) || {
  printf '%s\n' "$ipc_output" >&2
  printf '%s\n' "Network debug capture is unavailable. Set Config.networkDebug.enabled to true and reload Quickshell." >&2
  exit 1
}
if [[ $ipc_output == *"Target not found"* ]]; then
  printf '%s\n' "$ipc_output" >&2
  printf '%s\n' "Network debug capture is unavailable. Set Config.networkDebug.enabled to true and reload Quickshell." >&2
  exit 1
fi

for image in menu network-list; do
  for _ in $(seq 1 50); do
    if [[ -s "$output_directory/$image.png" ]]; then
      break
    fi
    sleep 0.1
  done
  if [[ ! -s "$output_directory/$image.png" ]]; then
    printf '%s\n' "Timed out waiting for $image.png" >&2
    exit 1
  fi
done

grim "$output_directory/compositor.png"
quickshell log -t 40 > "$output_directory/runtime.log"
quickshell ipc call network-debug close
printf '%s\n' "Network captures saved to $output_directory"
