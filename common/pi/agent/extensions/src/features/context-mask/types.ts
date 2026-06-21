import type { AgentMessage as CoreAgentMessage } from "@earendil-works/pi-agent-core";

export const CUSTOM_TYPE = "context-mask";
export const MASK_NOTICE_PREFIX = "[context masked:";
export const DEFAULT_TAIL_LINES = 20;
export const FAILED_BASH_TAIL_LINES = 40;
export const SUCCESS_BASH_TAIL_LINES = 10;
export const EDIT_TAIL_LINES = 30;
export const CODE_FILES_TAIL_LINES = 100;
export const RAW_RECENT_USER_TURNS = 1;
export const MIN_MASK_CHARACTERS = 600;
export const PRESERVED_HASHLINE_CONTEXTS = 1;
export const PRESERVED_EDIT_RESULTS = 1;

export type TextContent = { type: "text"; text: string };
export type ToolCallContent = { type: "toolCall"; id: string; name: string; arguments: Record<string, unknown> };
export type MessageContent = TextContent | ToolCallContent | { type: string; [key: string]: unknown };

export type ContextMessage = Omit<CoreAgentMessage, "role" | "content"> & {
  role: string;
  content?: string | MessageContent[];
  customType?: string;
  display?: boolean;
  toolCallId?: string;
  toolName?: string;
  details?: unknown;
  isError?: boolean;
};

export type ToolCallInfo = {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
};

export type MaskStats = {
  maskedCount: number;
  beforeCharacters: number;
  afterCharacters: number;
  tools: Map<string, number>;
  ids: string[];
  samples: string[];
};
