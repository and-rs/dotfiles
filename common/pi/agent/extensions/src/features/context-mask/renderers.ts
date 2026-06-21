import { Text } from "@earendil-works/pi-tui";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { formatStats, textFromContent } from "./summaries.ts";
import { CUSTOM_TYPE, type MessageContent } from "./types.ts";
import type { MaskStats } from "./types.ts";

export function registerContextMaskRenderer(pi: ExtensionAPI): (stats: MaskStats) => void {
  pi.registerMessageRenderer(CUSTOM_TYPE, (message, _options, theme) => {
    const content = typeof message.content === "string" ? message.content : textFromContent(message.content as unknown as MessageContent[]);
    const firstLine = content.split("\n", 1)[0] ?? "context";
    return new Text(`${theme.fg("thinkingHigh", "context")}\n${theme.fg("muted", firstLine)}`, 0, 0);
  });

  return (stats: MaskStats) => {
    pi.sendMessage({
      customType: CUSTOM_TYPE,
      content: formatStats(stats),
      display: true,
      details: { maskedCount: stats.maskedCount, beforeCharacters: stats.beforeCharacters, afterCharacters: stats.afterCharacters, toolCallIds: stats.ids, samples: stats.samples },
    }, { deliverAs: "nextTurn" });
  };
}
