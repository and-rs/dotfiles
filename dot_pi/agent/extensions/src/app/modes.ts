import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  type ExtensionAPI,
  type ExtensionContext,
  getAgentDir,
} from "@earendil-works/pi-coding-agent";

const CYCLE = ["plan", "build"] as const;
type CycleMode = (typeof CYCLE)[number];
export type Mode = CycleMode | "teach";

export const DISCOVERY_TOOLS = [
  "read",
  "grep",
  "find",
  "ls",
  "read-image",
  "web_search",
  "web_fetch",
] as const;

const BUILD_TOOLS = [...DISCOVERY_TOOLS, "bash", "edit", "write"] as const;

const WORKSPACE = `Stay in the current working directory. Do not search parent
dirs, $HOME, or absolute paths outside cwd unless the user asks. Prefer ls,
find, grep, then read. Stop when you can answer. Do not repeat a failed or
empty search with a near-identical query. Use web_search only for current
external docs, then web_fetch that URL.`;

const ENTRY = "agent-mode";

function loadLayer(mode: Mode): string {
  const path = join(getAgentDir(), "layers", `${mode}.md`);
  return readFileSync(path, "utf8").trim();
}

const LAYERS: Record<Mode, string> = {
  teach: loadLayer("teach"),
  plan: loadLayer("plan"),
  build: loadLayer("build"),
};

function toolsFor(mode: Mode): string[] {
  if (mode === "build") return [...BUILD_TOOLS];
  return [...DISCOVERY_TOOLS];
}

let cycle: CycleMode = "plan";
let overlay: "teach" | null = null;
let sessionStarted = false;
const modeListeners = new Set<() => void>();

function isCycle(value: unknown): value is CycleMode {
  return CYCLE.some((name) => name === value);
}

function modeNameFromEntry(entry: unknown): unknown {
  if (!entry || typeof entry !== "object") return undefined;
  if (!("type" in entry) || entry.type !== "custom") return undefined;
  if (!("customType" in entry) || entry.customType !== ENTRY) return undefined;
  if (!("data" in entry) || !entry.data || typeof entry.data !== "object") {
    return undefined;
  }
  if (!("name" in entry.data)) return undefined;
  return entry.data.name;
}

type AgentStartEvent = {
  systemPrompt?: unknown;
  systemPromptOptions?: { selectedTools?: string[] };
};

export function getMode(): Mode {
  if (overlay) return overlay;
  return cycle;
}

/** Test helper. Resets cycle/overlay without touching a session. */
export function resetModes(): void {
  cycle = "plan";
  overlay = null;
  sessionStarted = false;
}

export function onModeChange(listener: () => void): () => void {
  modeListeners.add(listener);
  return () => {
    modeListeners.delete(listener);
  };
}

export function registerModes(pi: ExtensionAPI): void {
  function apply(): void {
    pi.setActiveTools(toolsFor(getMode()));
    for (const listener of modeListeners) listener();
  }

  function dropOverlay(): void {
    if (!overlay) return;
    overlay = null;
    apply();
  }

  function setCycle(next: CycleMode): void {
    overlay = null;
    cycle = next;
    apply();
    pi.appendEntry(ENTRY, { name: cycle });
  }

  function restore(ctx: ExtensionContext): void {
    overlay = null;
    cycle = "plan";
    const entries = ctx.sessionManager.getEntries();
    for (let i = entries.length - 1; i >= 0; i--) {
      const name = modeNameFromEntry(entries[i]);
      if (!isCycle(name)) continue;
      cycle = name;
      return;
    }
  }

  pi.on("session_start", (_event, ctx) => {
    if (!sessionStarted) {
      sessionStarted = true;
      restore(ctx);
    }
    apply();
  });

  pi.on("session_tree", () => {
    apply();
  });

  pi.on("before_agent_start", (event) => {
    apply();
    const mode = getMode();
    const start = event as AgentStartEvent;
    if (start.systemPromptOptions) {
      start.systemPromptOptions.selectedTools = toolsFor(mode);
    }
    let base = "";
    if (typeof start.systemPrompt === "string") base = start.systemPrompt;
    return {
      systemPrompt: `${base}\n\n<active-agent-mode>${mode}</active-agent-mode>\nTreat active-agent-mode as authoritative runtime state. Do not infer current mode from files, previous messages, or layer names.\n\n${LAYERS[mode]}\n\n${WORKSPACE}`,
    };
  });

  pi.on("agent_settled", () => {
    dropOverlay();
  });

  pi.registerCommand("teach", {
    description: "One-shot coaching turn. Does not implement.",
    handler: async (args, ctx) => {
      const question = args.trim();
      if (!question) {
        ctx.ui.notify("Usage: /teach <question>", "warning");
        return;
      }
      if (!ctx.isIdle()) {
        ctx.ui.notify("Agent is busy", "warning");
        return;
      }
      overlay = "teach";
      apply();

      const abort = (): void => {
        if (overlay !== "teach") return;
        overlay = null;
        apply();
        ctx.ui.notify("Teach send failed", "warning");
      };

      try {
        await Promise.resolve(pi.sendUserMessage(question));
      } catch {
        abort();
      }
    },
  });

  pi.registerShortcut("alt+m", {
    description: "Cycle plan / build",
    handler: () => {
      if (overlay) {
        dropOverlay();
        return;
      }
      const index = CYCLE.indexOf(cycle);
      const next = CYCLE[(index + 1) % CYCLE.length];
      if (!next) return;
      setCycle(next);
    },
  });
}
