type BlockedToolName = "edit" | "write" | "grep" | "find" | "ls";

export const BLOCKED_TOOLS = new Set<BlockedToolName>(["edit", "write", "grep", "find", "ls"]);

const BASH_BLOCKED: Record<string, string> = {
  cat: "Use read for direct file reading; use hashline-edit only when editing that file.",
  head: "Use read for direct file reading; use hashline-edit only when editing that file.",
  tail: "Use read for direct file reading; use hashline-edit only when editing that file.",
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
    case "edit":
      return "Use hashline-edit; first call uses {path, goal}, staged follow-up call uses edits.";
    case "write":
      return "Use file-create for new files, hashline-edit for existing files.";
    case "grep":
      return "Use code-search for code search.";
    case "find":
    case "ls":
      return "Use code-overview or code-files for repo exploration.";
    default:
      return "Use the configured replacement tools.";
  }
}

export function isBlockedToolName(value: string): value is BlockedToolName {
  return BLOCKED_TOOLS.has(value as BlockedToolName);
}
