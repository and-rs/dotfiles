import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export const READ_ONLY_MODEL_TOOL_NAMES = [
  "code-overview",
  "code-search",
  "code-files",
  "code-view",
  "quickfix-handoff",
  "read-image",
  "exa-search",
  "web-fetch",
] as const;

function applyReadOnlyProfile(pi: ExtensionAPI): void {
  pi.setActiveTools([...READ_ONLY_MODEL_TOOL_NAMES]);
}

export function registerReadOnlyProfile(pi: ExtensionAPI): void {
  pi.on("session_start", () => applyReadOnlyProfile(pi));
  pi.on("session_tree", () => applyReadOnlyProfile(pi));
}
