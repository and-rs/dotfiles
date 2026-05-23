import type {
  ContextMessage,
  MaskStats,
  MessageContent,
  ToolCallInfo,
} from "./types.ts";
import {
  CODE_FILES_TAIL_LINES,
  DEFAULT_TAIL_LINES,
  EDIT_TAIL_LINES,
  FAILED_BASH_TAIL_LINES,
  MASK_NOTICE_PREFIX,
  PRESERVED_EDIT_RESULTS,
  PRESERVED_HASHLINE_READS,
  RAW_RECENT_USER_TURNS,
  SUCCESS_BASH_TAIL_LINES,
} from "./types.ts";

export function textFromContent(content: ContextMessage["content"]): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .filter(
      (part): part is MessageContent & { type: "text"; text: string } =>
        part.type === "text" &&
        typeof (part as { text?: unknown }).text === "string",
    )
    .map((part) => part.text)
    .join("\n");
}

export function lineCount(value: string): number {
  return value.length === 0 ? 0 : value.split("\n").length;
}

export function tailLines(value: string, count: number): string {
  if (count <= 0) return "";
  const lines = value.split("\n");
  if (lines.length <= count) return value;
  return lines.slice(-count).join("\n");
}

export function preview(value: unknown, maxLength = 160): string {
  const text = typeof value === "string" ? value : JSON.stringify(value ?? "");
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength - 1)}…`;
}

export function extractUrls(value: string, limit = 12): string[] {
  const matches = value.match(/https?:\/\/[^\s)\]}>\"]+/g) ?? [];
  return Array.from(new Set(matches)).slice(0, limit);
}

export function formatCharacters(value: number): string {
  if (value < 1000) return `${value} chars`;
  if (value < 1000 * 1000) return `${(value / 1000).toFixed(1)}k chars`;
  return `${(value / (1000 * 1000)).toFixed(1)}M chars`;
}

export function formatPercent(value: number): string {
  return `${value.toFixed(1)}%`;
}

export function normalizeToolName(name: string | undefined): string {
  return (name ?? "unknown").replaceAll("_", "-");
}

export function summarizeToolResult(
  message: ContextMessage,
  toolCall: ToolCallInfo | undefined,
): string {
  const toolName = normalizeToolName(message.toolName ?? toolCall?.name);
  const args = toolCall?.arguments ?? {};
  const text = textFromContent(message.content);
  const lines = lineCount(text);
  const status = message.isError ? "error" : "ok";
  let tailLineCount = DEFAULT_TAIL_LINES;
  const header = [
    `${MASK_NOTICE_PREFIX} old tool result]`,
    `tool: ${toolName}`,
    `status: ${status}`,
    `size: ${lines} lines, ${formatCharacters(text.length)}`,
  ];
  if (toolName === "bash") {
    tailLineCount = message.isError
      ? FAILED_BASH_TAIL_LINES
      : SUCCESS_BASH_TAIL_LINES;
    header.push(`command: ${preview(args.command)}`);
  } else if (toolName === "hashline-read") {
    tailLineCount = 0;
    header.push(`path: ${preview(args.path)}`);
    if (args.offset !== undefined)
      header.push(`offset: ${preview(args.offset)}`);
    if (args.limit !== undefined) header.push(`limit: ${preview(args.limit)}`);
    header.push(
      "note: body intentionally omitted; re-read for fresh file context and fresh anchors before edit.",
    );
  } else if (toolName === "hashline-edit" || toolName === "file-create") {
    tailLineCount = EDIT_TAIL_LINES;
    header.push(
      "note: old diff trimmed; inspect git diff for current worktree state.",
    );
  } else if (toolName === "code-files") {
    tailLineCount = CODE_FILES_TAIL_LINES;
    header.push(`path: ${preview(args.path ?? ".")}`);
    if (args.glob !== undefined) header.push(`glob: ${preview(args.glob)}`);
    if (args.type !== undefined) header.push(`type: ${preview(args.type)}`);
  } else if (toolName === "web-fetch") {
    tailLineCount = 0;
    header.push(`url: ${preview(args.url, 2000)}`);
    header.push("note: fetched body omitted; refetch URL if needed.");
  } else if (toolName === "exa-search") {
    tailLineCount = 0;
    header.push(`query: ${preview(args.query, 500)}`);
    const urls = extractUrls(text);
    if (urls.length > 0) {
      header.push("urls:");
      header.push(...urls.map((url) => `- ${url}`));
    }
  } else if (Object.keys(args).length > 0) {
    header.push(`args: ${preview(args)}`);
  }
  const tail = tailLines(text.trimEnd(), tailLineCount).trimEnd();
  if (tail) {
    header.push("tail:");
    header.push(tail);
  }
  return header.join("\n");
}

export function formatTreeItems(items: string[], indent = ""): string[] {
  return items.map(
    (item, index) =>
      `${indent}${index === items.length - 1 ? "└──" : "├──"} ${item}`,
  );
}

export function formatStats(stats: MaskStats): string {
  const saved = Math.max(0, stats.beforeCharacters - stats.afterCharacters);
  const savedPercent =
    stats.beforeCharacters === 0 ? 0 : (saved / stats.beforeCharacters) * 100;
  const toolItems = Array.from(stats.tools.entries())
    .sort((a, b) => b[1] - a[1])
    .map(([name, count]) => `${String(count).padStart(3)}  ${name}`);
  return [
    `${formatCharacters(stats.beforeCharacters).padStart(8)} → ${formatCharacters(stats.afterCharacters).padStart(8)}  saved ${formatCharacters(saved)} (${formatPercent(savedPercent)})`,
    `         ├── masked ${stats.maskedCount} old tool result${stats.maskedCount === 1 ? "" : "s"}`,
    "         ├── policy",
    "         │   ├── current turn kept raw",
    `         │   ├── latest ${RAW_RECENT_USER_TURNS} user turn${RAW_RECENT_USER_TURNS === 1 ? "" : "s"} kept raw`,
    `         │   ├── preserve ${PRESERVED_HASHLINE_READS} recent hashline read${PRESERVED_HASHLINE_READS === 1 ? "" : "s"}`,
    `         │   └── preserve ${PRESERVED_EDIT_RESULTS} recent edit diff${PRESERVED_EDIT_RESULTS === 1 ? "" : "s"}`,
    "         ├── tools",
    ...formatTreeItems(toolItems, "         │   "),
    "         └── samples",
    ...formatTreeItems(stats.samples, "             "),
  ].join("\n");
}
