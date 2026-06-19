import type { AgentMessage as CoreAgentMessage } from "@earendil-works/pi-agent-core";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { maskContext } from "./mask.ts";
import { registerContextMaskRenderer } from "./renderers.ts";

export default function registerContextMaskFeature(pi: ExtensionAPI): void {
  let lastLogKey = "";
  const publishStats = registerContextMaskRenderer(pi);

  pi.on("context", (event) => {
    const { messages, stats } = maskContext(event.messages as unknown as CoreAgentMessage[]);
    if (stats.maskedCount > 0) {
      const logKey = `${stats.ids.join(",")}:${stats.beforeCharacters}:${stats.afterCharacters}`;
      if (logKey !== lastLogKey) {
        lastLogKey = logKey;
        publishStats(stats);
      }
    }
    return { messages };
  });
}
