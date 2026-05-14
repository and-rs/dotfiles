import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const BLOCKED_TOOLS = new Set(["read", "edit", "write", "grep", "find", "ls"]);

const BASH_BLOCKED: Record<string, string> = {
  cat: "Use hashline-read to read file content.",
  head: "Use hashline-read with limit parameter for partial reads.",
  tail: "Use hashline-read with offset parameter for partial reads.",
  ls: "Use code-files for directory listing or code-overview for repo structure.",
  find: "Use code-files for file path discovery.",
  grep: "Use code-search for content search.",
};

function bashBlockedReason(command: unknown): string | null {
  if (typeof command !== "string") return null;
  const token = command.trimStart().split(/\s+/)[0] ?? "";
  const base = token.split("/").at(-1) ?? token;
  const hint = BASH_BLOCKED[base];
  if (!hint) return null;
  return `bash ${base} is blocked by tool-policy. ${hint}`;
}

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
    if (BLOCKED_TOOLS.has(event.toolName)) {
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
