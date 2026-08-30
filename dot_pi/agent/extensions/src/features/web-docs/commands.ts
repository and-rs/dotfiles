import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { AUTH_PATH, clearExaKey, formatExaSource, resolveExaKey, saveExaKey } from "./lib/exa-auth.ts";
import { computeExaUsageSummary } from "./exa.ts";

export function registerWebDocsCommands(pi: ExtensionAPI): void {
  pi.registerCommand("exa", {
    description: "Configure Exa API key for web search",
    getArgumentCompletions: (prefix) => {
      const items = ["login", "status", "logout", "service-login", "service-status", "service-logout", "usage"];
      return items.filter((item) => item.startsWith(prefix)).map((value) => ({ value, label: value }));
    },
    handler: async (args, ctx) => {
      let action = args.trim().toLowerCase();
      if (!action) {
        const choice = await ctx.ui.select("Exa", ["login", "status", "logout", "service-login", "service-status", "service-logout", "usage"]);
        if (!choice) {
          ctx.ui.notify("Cancelled", "info");
          return;
        }
        action = choice;
      }
      if (action === "login") {
        const value = await ctx.ui.input("Exa API key", "exa_...");
        if (!value?.trim()) return ctx.ui.notify("No key saved", "info");
        await saveExaKey("api", value);
        return ctx.ui.notify(`Saved Exa key to ${AUTH_PATH}`, "info");
      }
      if (action === "service-login") {
        const value = await ctx.ui.input("Exa service API key", "exa_...");
        if (!value?.trim()) return ctx.ui.notify("No service key saved", "info");
        await saveExaKey("service", value);
        return ctx.ui.notify(`Saved Exa service key to ${AUTH_PATH}`, "info");
      }
      if (action === "status") {
        const resolved = await resolveExaKey("api");
        if (!resolved.key || !resolved.source) return ctx.ui.notify("Exa not configured", "warning");
        return ctx.ui.notify(`Exa configured via ${formatExaSource("api", resolved.source)}`, "info");
      }
      if (action === "service-status") {
        const resolved = await resolveExaKey("service");
        if (!resolved.key || !resolved.source) return ctx.ui.notify("Exa service key not configured", "warning");
        return ctx.ui.notify(`Exa service key configured via ${formatExaSource("service", resolved.source)}`, "info");
      }
      if (action === "usage") {
        const resolved = await resolveExaKey("service");
        if (!resolved.key) return ctx.ui.notify("Exa service key not configured. Use /exa service-login.", "warning");
        try {
          return ctx.ui.notify(await computeExaUsageSummary(resolved.key), "info");
        } catch (error) {
          const message = error instanceof Error ? error.message : "unknown error";
          return ctx.ui.notify(`Exa usage unavailable: ${message}`, "error");
        }
      }
      if (action === "logout") {
        const cleared = await clearExaKey("api");
        return ctx.ui.notify(cleared ? "Removed stored Exa key" : "No stored Exa key", "info");
      }
      if (action === "service-logout") {
        const cleared = await clearExaKey("service");
        return ctx.ui.notify(cleared ? "Removed stored Exa service key" : "No stored Exa service key", "info");
      }
      ctx.ui.notify("Usage: /exa [login|status|logout|service-login|service-status|service-logout|usage]", "error");
    },
  });
}
