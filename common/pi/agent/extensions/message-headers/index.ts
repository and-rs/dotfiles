import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const CUSTOM_TYPE = "agent-header";

export default function messageHeadersExtension(pi: ExtensionAPI) {
  pi.registerMessageRenderer(CUSTOM_TYPE, (_message, _options, theme) => {
    return {
      render(width: number): string[] {
        const label = " Agent ";
        const prefix = "─";
        const fill = "─".repeat(Math.max(0, width - label.length - prefix.length));
        return [theme.fg("muted", prefix + label + fill)];
      },
      invalidate() {},
    };
  });

  pi.on("turn_start", async (_event, _ctx) => {
    pi.sendMessage({ customType: CUSTOM_TYPE, content: "", display: true });
  });

  // Claude 4.6+ removed assistant prefill support — strip trailing assistant messages
  // before the request is sent so all providers (Copilot, Vertex, direct) work correctly.
  pi.on("before_provider_request", (event, _ctx) => {
    const payload = event.payload as { messages?: Array<{ role: string }>; model?: string };
    const msgs = payload.messages;
    if (!Array.isArray(msgs) || msgs.length === 0) return;

    const model = typeof payload.model === "string" ? payload.model : "";
    const noPrefix = (s: string) => s.includes("4-6") || s.includes("4.6") || s.includes("4-7") || s.includes("4.7");
    if (!noPrefix(model)) return;

    const last = msgs[msgs.length - 1];
    if (last.role !== "assistant") return;

    const trimmed = [...msgs];
    while (trimmed.length > 0 && trimmed[trimmed.length - 1].role === "assistant") trimmed.pop();
    if (trimmed.length === 0) return;

    return { ...payload, messages: trimmed };
  });

  pi.on("context", async (event, _ctx) => {
    const filtered = event.messages.filter((m) => {
      const msg = m as { role?: string; customType?: string };
      return !(msg.role === "custom" && msg.customType === CUSTOM_TYPE);
    });
    if (filtered.length === event.messages.length) return;
    return { messages: filtered };
  });
}
