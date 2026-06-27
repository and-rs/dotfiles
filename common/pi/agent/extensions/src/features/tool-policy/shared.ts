const BLOCKED_TOOLS = new Set(["edit", "write", "read", "grep", "find", "ls"] as const);

const BASH_BLOCKED: Record<string, string> = {
  anchorline: "Use anchorline-show before anchorline-edit; do not shell-wrap anchorline.",
  sed: "Use anchorline-edit or file-create, not sed rewrite.",
  python: "Use anchorline-edit or file-create, not inline python rewrite.",
  python3: "Use anchorline-edit or file-create, not inline python rewrite.",
  perl: "Use anchorline-edit or file-create, not perl rewrite.",
  awk: "Use anchorline-edit or file-create, not awk rewrite.",
  cat: "Use anchorline-show for text files or read-image for images.",
  head: "Use anchorline-show for text files.",
  tail: "Use anchorline-show for text files.",
  ls: "Use code-files for directory listing or code-overview for repo structure.",
  find: "Use code-files for file path discovery.",
  grep: "Use code-search for content search.",
};

export function bashBlockedReason(command: unknown): string | null {
  if (typeof command !== "string") return null;
  const normalized = command.trimStart();
  const token = normalized.split(/\s+/)[0] ?? "";
  const base = token.split("/").at(-1) ?? token;
  const hint = BASH_BLOCKED[base];
  if (hint) return `bash ${base} is blocked by tool-policy. ${hint}`;
  for (const [trigger, reason] of REWRITE_ESCAPE_HATCHES) {
    if (normalized.includes(trigger)) return reason;
  }
  return null;
}

const REWRITE_ESCAPE_HATCHES: Array<[string, string]> = [
  ["sed ", "bash sed is blocked by tool-policy. Use anchorline-edit or file-create."],
  ["python ", "bash python is blocked by tool-policy. Use anchorline-edit or file-create."],
  ["python3 ", "bash python3 is blocked by tool-policy. Use anchorline-edit or file-create."],
  ["perl ", "bash perl is blocked by tool-policy. Use anchorline-edit or file-create."],
  ["awk ", "bash awk is blocked by tool-policy. Use anchorline-edit or file-create."],
  ["node ", "bash node is blocked by tool-policy. Use anchorline-edit or file-create."],
];

export function replacementFor(toolName: string): string {
  switch (toolName) {
    case "edit":
      return "Use anchorline-edit for existing files or file-create for new files.";
    case "write":
      return "Use file-create for new files.";
    case "read":
      return "Use anchorline-show for text files or read-image for images.";
    case "grep":
      return "Use code-search for code search.";
    case "find":
    case "ls":
      return "Use code-overview or code-files for repo exploration.";
    default:
      return "Use the configured replacement tools.";
  }
}

export function isBlockedToolName(value: string): value is "edit" | "write" | "read" | "grep" | "find" | "ls" {
  return BLOCKED_TOOLS.has(value as "edit" | "write" | "read" | "grep" | "find" | "ls");
}
