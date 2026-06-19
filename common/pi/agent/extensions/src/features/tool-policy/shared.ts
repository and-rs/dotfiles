type BlockedToolName = "read" | "edit" | "write" | "grep" | "find" | "ls";

export const BLOCKED_TOOLS = new Set<BlockedToolName>(["read", "edit", "write", "grep", "find", "ls"]);

const BASH_BLOCKED: Record<string, string> = {
  cat: "Use hashline-edit with {path, goal} when you need fresh edit-targeted file context.",
  head: "Use hashline-edit with {path, goal}; large files return segment labels for staged edit context.",
  tail: "Use hashline-edit with {path, goal}; large files return segment labels for staged edit context.",
  ls: "Use code-files for directory listing or code-overview for repo structure.",
  find: "Use code-files for file path discovery.",
  grep: "Use code-search for content search.",
};

export function bashBlockedReason(command: unknown): string | null {
  if (typeof command !== "string") return null;
  const token = command.trimStart().split(/\s+/)[0] ?? "";
  const base = token.split("/").at(-1) ?? token;
  const hint = BASH_BLOCKED[base];
  if (!hint) return null;
  return `bash ${base} is blocked by tool-policy. ${hint}`;
}

export function replacementFor(toolName: string): string {
  switch (toolName) {
    case "read":
      return "Use hashline-edit with {path, goal} when you need fresh edit-targeted file context.";
    case "edit":
      return "Use hashline-edit; first call uses {path, goal}, staged follow-up call uses edits.";
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

export function isBlockedToolName(value: string): value is BlockedToolName {
  return BLOCKED_TOOLS.has(value as BlockedToolName);
}
