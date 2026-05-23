import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { basename } from "node:path";

function defaultSessionName(cwd: string): string {
  return basename(cwd) || cwd;
}

async function promptForSessionName(pi: ExtensionAPI, ctx: ExtensionContext): Promise<void> {
  const value = (await ctx.ui.input("Session name", defaultSessionName(ctx.cwd)))?.trim();
  if (!value) {
    return;
  }

  pi.setSessionName(value);
  ctx.ui.notify(`Session named: ${value}`, "info");
}

export function registerSessionNameEvents(pi: ExtensionAPI): void {
  pi.on("session_start", async (event, ctx) => {
    if (!ctx.hasUI || event.reason === "reload") {
      return;
    }
    if (pi.getSessionName()?.trim()) {
      return;
    }

    await promptForSessionName(pi, ctx);
  });
}
