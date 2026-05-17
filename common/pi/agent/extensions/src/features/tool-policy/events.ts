import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { BLOCKED_TOOLS, bashBlockedReason, isBlockedToolName, replacementFor } from "./shared.ts";

function applyToolPolicy(pi: ExtensionAPI): void {
  const active = pi.getActiveTools();
  const filtered = active.filter((name) => !isBlockedToolName(name));
  if (filtered.length !== active.length) {
    pi.setActiveTools(filtered);
  }
}

export function registerToolPolicyEvents(pi: ExtensionAPI): void {
  pi.on("session_start", () => {
    applyToolPolicy(pi);
  });

  pi.on("session_tree", () => {
    applyToolPolicy(pi);
  });

  pi.on("tool_call", (event) => {
    if (isBlockedToolName(event.toolName)) {
      return {
        block: true,
        reason: `${event.toolName} is disabled by tool-policy. ${replacementFor(event.toolName)}`,
      };
    }
    if (event.toolName === "bash") {
      const reason = bashBlockedReason(event.input.command);
      if (reason) return { block: true, reason };
    }
  });
}
