import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

export const MODES = ["teach", "plan", "build"] as const;
export type Mode = (typeof MODES)[number];

export const DISCOVERY_TOOLS = [
  "code-overview",
  "code-search",
  "code-files",
  "code-view",
  "quickfix-handoff",
  "read-image",
  "exa-search",
  "web-fetch",
] as const;

const BUILD_TOOLS = [
  ...DISCOVERY_TOOLS,
  "read",
  "bash",
  "edit",
  "write",
  "grep",
  "find",
  "ls",
] as const;

const ENTRY = "agent-mode";

function loadLayer(mode: Mode): string {
  const path = join(homedir(), ".pi", "agent", "layers", `${mode}.md`);
  return readFileSync(path, "utf8").trim();
}

const LAYERS: Record<Mode, string> = {
  teach: loadLayer("teach"),
  plan: loadLayer("plan"),
  build: loadLayer("build"),
};

function toolsFor(mode: Mode): string[] {
  return mode === "build" ? [...BUILD_TOOLS] : [...DISCOVERY_TOOLS];
}

function isMode(value: unknown): value is Mode {
  return MODES.some((mode) => mode === value);
}

export function registerModes(pi: ExtensionAPI): void {
  let mode: Mode = "teach";

  function apply(ctx?: ExtensionContext): void {
    pi.setActiveTools(toolsFor(mode));
    if (!ctx?.hasUI) return;
    ctx.ui.setStatus("mode", ctx.ui.theme.fg("accent", mode));
  }

  function setMode(next: Mode, ctx?: ExtensionContext): void {
    mode = next;
    apply(ctx);
    pi.appendEntry(ENTRY, { name: mode });
  }

  function restore(ctx: ExtensionContext): void {
    const entries = ctx.sessionManager.getEntries();
    const last = [...entries]
      .reverse()
      .find(
        (entry) =>
          entry.type === "custom" &&
          "customType" in entry &&
          entry.customType === ENTRY,
      ) as { data?: { name?: unknown } } | undefined;
    if (isMode(last?.data?.name)) mode = last.data.name;
  }

  pi.on("session_start", (_event, ctx) => {
    restore(ctx);
    apply(ctx);
  });

  pi.on("session_tree", (_event, ctx) => {
    apply(ctx);
  });

  pi.on("before_agent_start", (event) => ({
    systemPrompt: `${event.systemPrompt}\n\n${LAYERS[mode]}`,
  }));

  pi.registerShortcut("tab", {
    description: "Cycle teach / plan / build",
    handler: (ctx) => {
      const index = MODES.indexOf(mode);
      setMode(MODES[(index + 1) % MODES.length], ctx);
    },
  });
}
