import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { AgentMessage as CoreAgentMessage } from "@earendil-works/pi-agent-core";
import { Text } from "@earendil-works/pi-tui";

const CUSTOM_TYPE = "context-mask";
const MASK_NOTICE_PREFIX = "[context masked:";
const KEEP_TAIL_LINES = 40;
const MIN_MASK_CHARACTERS = 1000;

type TextContent = { type: "text"; text: string };
type ToolCallContent = { type: "toolCall"; id: string; name: string; arguments: Record<string, unknown> };
type MessageContent = TextContent | ToolCallContent | { type: string; [key: string]: unknown };

type ContextMessage = CoreAgentMessage & {
  role: string;
  content?: string | MessageContent[];
  customType?: string;
  display?: boolean;
  toolCallId?: string;
  toolName?: string;
  details?: unknown;
  isError?: boolean;
};

type ToolCallInfo = {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
};

type MaskStats = {
  maskedCount: number;
  beforeCharacters: number;
  afterCharacters: number;
  tools: Map<string, number>;
  ids: string[];
  samples: string[];
};

function isTextContent(part: MessageContent): part is TextContent {
  return part.type === "text" && typeof (part as TextContent).text === "string";
}

function isToolCallContent(part: MessageContent): part is ToolCallContent {
  return part.type === "toolCall" && typeof (part as ToolCallContent).id === "string";
}

function textFromContent(content: ContextMessage["content"]): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content.filter(isTextContent).map((part) => part.text).join("\n");
}

function lineCount(value: string): number {
  return value.length === 0 ? 0 : value.split("\n").length;
}

function tailLines(value: string, count: number): string {
  const lines = value.split("\n");
  if (lines.length <= count) return value;
  return lines.slice(-count).join("\n");
}

function preview(value: unknown, maxLength = 160): string {
  const text = typeof value === "string" ? value : JSON.stringify(value ?? "");
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength - 1)}…`;
}

function formatCharacters(value: number): string {
  if (value < 1000) return `${value} chars`;
  if (value < 1000 * 1000) return `${(value / 1000).toFixed(1)}k chars`;
  return `${(value / (1000 * 1000)).toFixed(1)}M chars`;
}

function formatPercent(value: number): string {
  return `${value.toFixed(1)}%`;
}

function buildToolCallMap(messages: ContextMessage[]): Map<string, ToolCallInfo> {
  const toolCalls = new Map<string, ToolCallInfo>();
  for (const message of messages) {
    if (message.role !== "assistant" || !Array.isArray(message.content)) continue;
    for (const rawPart of message.content) {
      const part = rawPart as MessageContent;
      if (!isToolCallContent(part)) continue;
      toolCalls.set(part.id, { id: part.id, name: part.name, arguments: part.arguments ?? {} });
    }
  }
  return toolCalls;
}

function findCurrentTurnStart(messages: ContextMessage[]): number {
  for (let i = messages.length - 1; i >= 0; i--) {
    if (messages[i].role === "user") return i;
  }
  return messages.length;
}

function isContextLog(message: ContextMessage): boolean {
  return message.role === "custom" && message.customType === CUSTOM_TYPE;
}

function shouldMask(message: ContextMessage, index: number, currentTurnStart: number): boolean {
  if (index >= currentTurnStart) return false;
  if (message.role !== "toolResult") return false;
  const text = textFromContent(message.content);
  if (text.startsWith(MASK_NOTICE_PREFIX)) return false;
  return text.length >= MIN_MASK_CHARACTERS;
}

function summarizeToolResult(message: ContextMessage, toolCall: ToolCallInfo | undefined): string {
  const toolName = message.toolName ?? toolCall?.name ?? "unknown";
  const args = toolCall?.arguments ?? {};
  const text = textFromContent(message.content);
  const lines = lineCount(text);
  const status = message.isError ? "error" : "ok";
  const tail = tailLines(text.trimEnd(), KEEP_TAIL_LINES).trimEnd();
  const header = [
    `${MASK_NOTICE_PREFIX} old tool result]`,
    `tool: ${toolName}`,
    `status: ${status}`,
    `size: ${lines} lines, ${formatCharacters(text.length)}`,
  ];

  if (toolName === "bash") {
    header.push(`command: ${preview(args.command)}`);
  } else if (toolName === "hashline_read") {
    header.push(`path: ${preview(args.path)}`);
    header.push("note: file body omitted; use hashline_read again for exact anchors before editing.");
  } else if (toolName === "grep") {
    header.push(`query: ${preview(args.pattern)}`);
    header.push(`path: ${preview(args.path ?? ".")}`);
  } else if (toolName === "find") {
    header.push(`pattern: ${preview(args.pattern)}`);
    header.push(`path: ${preview(args.path ?? ".")}`);
  } else if (toolName === "ls") {
    header.push(`path: ${preview(args.path ?? ".")}`);
  } else if (toolName === "web_fetch") {
    header.push(`url: ${preview(args.url)}`);
  } else if (Object.keys(args).length > 0) {
    header.push(`args: ${preview(args)}`);
  }

  if (tail) {
    header.push("tail:");
    header.push(tail);
  }

  return header.join("\n");
}

function maskContext(messages: CoreAgentMessage[]): { messages: CoreAgentMessage[]; stats: MaskStats } {
  const sourceMessages = messages.filter((message) => !isContextLog(message as ContextMessage)) as ContextMessage[];
  const toolCalls = buildToolCallMap(sourceMessages);
  const currentTurnStart = findCurrentTurnStart(sourceMessages);
  const stats: MaskStats = {
    maskedCount: 0,
    beforeCharacters: 0,
    afterCharacters: 0,
    tools: new Map<string, number>(),
    ids: [],
    samples: [],
  };
  const nextMessages = sourceMessages.map((message, index) => {
    if (!shouldMask(message, index, currentTurnStart)) return message;

    const toolCallId = typeof message.toolCallId === "string" ? message.toolCallId : "unknown";
    const toolCall = toolCalls.get(toolCallId);
    const toolName = message.toolName ?? toolCall?.name ?? "unknown";
    const beforeText = textFromContent(message.content);
    const afterText = summarizeToolResult(message, toolCall);

    stats.maskedCount += 1;
    stats.beforeCharacters += beforeText.length;
    stats.afterCharacters += afterText.length;
    stats.tools.set(toolName, (stats.tools.get(toolName) ?? 0) + 1);
    stats.ids.push(toolCallId);
    if (stats.samples.length < 6) {
      stats.samples.push(`${toolName} ${formatCharacters(beforeText.length)}→${formatCharacters(afterText.length)}`);
    }

    return {
      ...message,
      content: [{ type: "text", text: afterText }],
      details: {
        ...(typeof message.details === "object" && message.details !== null ? message.details : {}),
        contextMasked: true,
        originalCharacters: beforeText.length,
        maskedCharacters: afterText.length,
      },
    } as CoreAgentMessage;
  });

  return { messages: nextMessages, stats };
}

function formatTreeItems(items: string[], indent = ""): string[] {
  return items.map((item, index) => `${indent}${index === items.length - 1 ? "└──" : "├──"} ${item}`);
}

function formatStats(stats: MaskStats): string {
  const saved = Math.max(0, stats.beforeCharacters - stats.afterCharacters);
  const savedPercent = stats.beforeCharacters === 0 ? 0 : (saved / stats.beforeCharacters) * 100;
  const toolItems = Array.from(stats.tools.entries())
    .sort((a, b) => b[1] - a[1])
    .map(([name, count]) => `${String(count).padStart(3)}  ${name}`);
  const sampleItems = stats.samples;

  return [
    `${formatCharacters(stats.beforeCharacters).padStart(8)} → ${formatCharacters(stats.afterCharacters).padStart(8)}  saved ${formatCharacters(saved)} (${formatPercent(savedPercent)})`,
    `         ├── masked ${stats.maskedCount} old tool result${stats.maskedCount === 1 ? "" : "s"}`,
    "         ├── policy",
    "         │   ├── current turn kept raw",
    `         │   └── old outputs keep metadata + tail ${KEEP_TAIL_LINES} lines`,
    "         ├── tools",
    ...formatTreeItems(toolItems, "         │   "),
    "         └── samples",
    ...formatTreeItems(sampleItems, "             "),
  ].join("\n");
}

export default function contextMaskExtension(pi: ExtensionAPI): void {
  let lastLogKey = "";

  pi.registerMessageRenderer(CUSTOM_TYPE, (message, _options, theme) => {
    const content = typeof message.content === "string" ? message.content : textFromContent(message.content as MessageContent[]);
    return new Text(`${theme.fg("thinkingHigh", "context")}\n${theme.fg("muted", content)}`, 0, 0);
  });

  pi.on("context", (event) => {
    const { messages, stats } = maskContext(event.messages);
    if (stats.maskedCount > 0) {
      const logKey = `${stats.ids.join(",")}:${stats.beforeCharacters}:${stats.afterCharacters}`;
      if (logKey !== lastLogKey) {
        lastLogKey = logKey;
        pi.sendMessage(
          {
            customType: CUSTOM_TYPE,
            content: formatStats(stats),
            display: true,
            details: {
              maskedCount: stats.maskedCount,
              beforeCharacters: stats.beforeCharacters,
              afterCharacters: stats.afterCharacters,
              toolCallIds: stats.ids,
              samples: stats.samples,
            },
          },
          { deliverAs: "nextTurn" },
        );
      }
    }
    return { messages };
  });
}
