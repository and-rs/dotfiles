import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  installChromeFooter,
  renderContextStatus,
  renderModelStatus,
  renderThinkingStatus,
} from "../ui/chrome.ts";

function refreshChromeStatus(ctx: ExtensionContext): void {
  renderModelStatus(ctx);
  renderContextStatus(ctx);
}

export function registerAppUi(pi: ExtensionAPI): void {
  pi.on("session_start", async (_event, ctx) => {
    installChromeFooter(ctx);
    refreshChromeStatus(ctx);
    renderThinkingStatus(ctx);
  });

  pi.on("model_select", async (_event, ctx) => {
    refreshChromeStatus(ctx);
  });

  pi.on("thinking_level_select", async (event, ctx) => {
    renderThinkingStatus(ctx, event.level);
    renderModelStatus(ctx);
  });

  pi.on("turn_end", async (_event, ctx) => {
    renderContextStatus(ctx);
  });
}