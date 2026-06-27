import type { AgentMessage as CoreAgentMessage } from "@earendil-works/pi-agent-core";
import {
  CUSTOM_TYPE,
  MIN_MASK_CHARACTERS,
  PRESERVED_FILE_CREATE_RESULTS,
  RAW_RECENT_USER_TURNS,
  type ContextMessage,
  type MaskStats,
  type MessageContent,
  type ToolCallContent,
  type ToolCallInfo,
} from "./types.ts";
import {
  normalizeToolName,
  summarizeToolResult,
  textFromContent,
} from "./summaries.ts";

function isToolCallContent(part: MessageContent): part is ToolCallContent {
  return (
    part.type === "toolCall" && typeof (part as ToolCallContent).id === "string"
  );
}

function buildToolCallMap(
  messages: ContextMessage[],
): Map<string, ToolCallInfo> {
  const toolCalls = new Map<string, ToolCallInfo>();
  for (const message of messages) {
    if (message.role !== "assistant" || !Array.isArray(message.content))
      continue;
    for (const rawPart of message.content) {
      const part = rawPart as MessageContent;
      if (!isToolCallContent(part)) continue;
      toolCalls.set(part.id, {
        id: part.id,
        name: part.name,
        arguments: part.arguments ?? {},
      });
    }
  }
  return toolCalls;
}

function findRecentTurnStart(
  messages: ContextMessage[],
  turns: number,
): number {
  let seen = 0;
  for (let i = messages.length - 1; i >= 0; i--) {
    if (messages[i].role !== "user") continue;
    seen += 1;
    if (seen === turns) return i;
  }
  return 0;
}

function isContextLog(message: ContextMessage): boolean {
  if (message.role !== "custom") return false;
  if (message.customType === CUSTOM_TYPE) return true;
  return message.display === false;
}

function preserveToolResultIds(
  messages: ContextMessage[],
  toolCalls: Map<string, ToolCallInfo>,
  rawWindowStart: number,
): Set<string> {
  const keep = new Set<string>();
  let keptFileCreates = 0;
  for (let i = messages.length - 1; i >= 0; i--) {
    if (i >= rawWindowStart) continue;
    const message = messages[i];
    if (message.role !== "toolResult") continue;
    const toolCallId =
      typeof message.toolCallId === "string" ? message.toolCallId : "";
    if (!toolCallId) continue;
    const toolCall = toolCalls.get(toolCallId);
    const toolName = normalizeToolName(message.toolName ?? toolCall?.name);
    if (toolName !== "file-create") continue;
    if (keptFileCreates >= PRESERVED_FILE_CREATE_RESULTS) continue;
    keep.add(toolCallId);
    keptFileCreates += 1;
  }
  return keep;
}

function shouldMask(
  message: ContextMessage,
  index: number,
  rawWindowStart: number,
  preservedIds: Set<string>,
): boolean {
  if (index >= rawWindowStart) return false;
  if (message.role !== "toolResult") return false;
  if (
    typeof message.toolCallId === "string" &&
    preservedIds.has(message.toolCallId)
  )
    return false;
  const text = textFromContent(message.content);
  return (
    !text.startsWith("[context masked:") && text.length >= MIN_MASK_CHARACTERS
  );
}

function anchorlineStateFromDetails(details: unknown): string | null {
  if (typeof details !== "object" || details === null) return null;
  const state = (details as { state?: unknown }).state;
  return typeof state === "string" ? state : null;
}

export function maskContext(messages: CoreAgentMessage[]): {
  messages: CoreAgentMessage[];
  stats: MaskStats;
} {
  const sourceMessages = messages.filter(
    (message) => !isContextLog(message as ContextMessage),
  ) as ContextMessage[];
  const toolCalls = buildToolCallMap(sourceMessages);
  const rawWindowStart = findRecentTurnStart(
    sourceMessages,
    RAW_RECENT_USER_TURNS,
  );
  const preservedIds = preserveToolResultIds(
    sourceMessages,
    toolCalls,
    rawWindowStart,
  );
  const stats: MaskStats = {
    maskedCount: 0,
    beforeCharacters: 0,
    afterCharacters: 0,
    tools: new Map(),
    ids: [],
    samples: [],
  };
  const nextMessages = sourceMessages.map((message, index) => {
    const toolCallId = typeof message.toolCallId === "string" ? message.toolCallId : "unknown";
    const toolCall = toolCalls.get(toolCallId);
    const toolName = normalizeToolName(message.toolName ?? toolCall?.name);
    const state = toolName === "anchorline-edit" ? anchorlineStateFromDetails(message.details) : null;
    const modelMessage = state === null ? message : { ...message, content: [{ type: "text", text: state }], details: { ...(typeof message.details === "object" && message.details !== null ? message.details : {}), anchorlineDeltaHidden: true } } as ContextMessage;
    if (!shouldMask(modelMessage, index, rawWindowStart, preservedIds)) return modelMessage;
    const beforeText = textFromContent(modelMessage.content);
    const afterText = summarizeToolResult(modelMessage, toolCall);
    stats.maskedCount += 1;
    stats.beforeCharacters += beforeText.length;
    stats.afterCharacters += afterText.length;
    stats.tools.set(toolName, (stats.tools.get(toolName) ?? 0) + 1);
    stats.ids.push(toolCallId);
    if (stats.samples.length < 6)
      stats.samples.push(
        `${toolName} ${beforeText.length} → ${afterText.length}`,
      );
    return {
      ...modelMessage,
      content: [{ type: "text", text: afterText }],
      details: {
        ...(typeof message.details === "object" && message.details !== null
          ? message.details
          : {}),
        contextMasked: true,
        originalCharacters: beforeText.length,
        maskedCharacters: afterText.length,
      },
    } as CoreAgentMessage;
  });
  return { messages: nextMessages as unknown as CoreAgentMessage[], stats };
}
