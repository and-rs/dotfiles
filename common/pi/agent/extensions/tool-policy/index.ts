import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const BLOCKED_TOOLS = new Set(["read", "edit", "write", "grep", "find", "ls"]);

function replacementFor(toolName: string): string {
  switch (toolName) {
    case "read":
      return "Use hashline-read for exact file ranges.";
    case "edit":
      return "Use hashline-edit for existing-file edits.";
    case "write":
      return "Use file-create for new files, hashline-edit for existing files.";
    case "grep":
      return "Use code-search for code search.";
    case "find":
    case "ls":
      return "Use code-overview or code-search for repo exploration.";
    default:
      return "Use the configured replacement tools.";
  }
}

function applyToolPolicy(pi: ExtensionAPI): void {
  const active = pi.getActiveTools();
  const filtered = active.filter((name) => !BLOCKED_TOOLS.has(name));
  if (filtered.length !== active.length) {
    pi.setActiveTools(filtered);
  }
}

export default function toolPolicyExtension(pi: ExtensionAPI): void {
  pi.on("session_start", () => {
    applyToolPolicy(pi);
  });

  pi.on("session_tree", () => {
    applyToolPolicy(pi);
  });

  pi.on("tool_call", (event) => {
    if (!BLOCKED_TOOLS.has(event.toolName)) return;
    return {
      block: true,
      reason: `${event.toolName} is disabled by tool-policy. ${replacementFor(event.toolName)}`,
    };
  });
}
