import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { phasePrompt } from "./prompt.ts";
import { FORGE_STATE_TYPE, createForgeState, isForged, isReadOnlyPhase, pushTouchedFiles, restoreForgeState } from "./state.ts";
import type { FileCreateDetails, ForgeState, HashlineEditDetails } from "./types.ts";
import { updateForgeUi } from "./ui.ts";

const READ_ONLY_TOOLS = [
  "bash",
  "code-overview",
  "code-search",
  "code-files",
  "hashline-read",
  "exa-search",
  "web-fetch",
];

const FULL_TOOLS = [
  "bash",
  "code-overview",
  "code-search",
  "code-files",
  "hashline-read",
  "hashline-edit",
  "file-create",
  "exa-search",
  "web-fetch",
];

const WRITE_LIKE_BASH_RE = /\b(rm|mv|cp|mkdir|touch|chmod|chown|ln|install|dd)\b|\b(sed|perl)\s+-i\b|\btee\b|>>|[^|]>|\bgit\s+(add|commit|reset|checkout|switch|restore|clean|apply|am|rebase|merge|cherry-pick|push|pull)\b|\bstash\s+(apply|pop|drop|clear)\b|\b(npm|pnpm|yarn|bun)\s+(add|install|update|remove|unlink)\b|\bpip\s+install\b|\bcargo\s+(add|install)\b/i;

type ForgeRuntime = {
  getState: () => ForgeState;
  setState: (state: ForgeState) => void;
  persistState: () => void;
  applyTools: () => void;
};

export function createForgeRuntime(pi: ExtensionAPI): ForgeRuntime {
  let state = createForgeState();

  return {
    getState: () => state,
    setState: (next) => {
      state = next;
    },
    persistState: () => {
      pi.appendEntry(FORGE_STATE_TYPE, state);
    },
    applyTools: () => {
      pi.setActiveTools(isReadOnlyPhase(state.phase) ? READ_ONLY_TOOLS : FULL_TOOLS);
    },
  };
}

export function registerForgeEvents(pi: ExtensionAPI, runtime: ForgeRuntime): void {
  pi.on("session_start", async (_event, ctx) => {
    const entry = ctx.sessionManager
      .getEntries()
      .filter(
        (item: { type: string; customType?: string }) =>
          item.type === "custom" && item.customType === FORGE_STATE_TYPE,
      )
      .pop() as { data?: ForgeState } | undefined;

    runtime.setState(restoreForgeState(entry?.data));
    runtime.applyTools();
    updateForgeUi(ctx, runtime.getState());
  });

  pi.on("before_agent_start", async (event) => {
    const state = runtime.getState();
    if (!isForged(state)) return;
    return {
      systemPrompt: `${event.systemPrompt}\n\n${phasePrompt(state, state.phase)}`,
    };
  });

  pi.on("tool_call", (event) => {
    const state = runtime.getState();
    if (!isReadOnlyPhase(state.phase)) return;
    if (event.toolName === "hashline-edit" || event.toolName === "file-create") {
      return {
        block: true,
        reason: `${state.phase} mode is read-only. Move to /forge exert or /forge refine for edits.`,
      };
    }
    if (event.toolName !== "bash") return;
    const command = typeof event.input.command === "string" ? event.input.command : "";
    if (!WRITE_LIKE_BASH_RE.test(command)) return;
    return {
      block: true,
      reason: `${state.phase} mode blocks write-like bash. Keep this phase read-only.`,
    };
  });

  pi.on("tool_result", async (event) => {
    if (event.toolName === "hashline-edit") {
      const details = event.details as HashlineEditDetails | undefined;
      const next = pushTouchedFiles(
        runtime.getState(),
        (details?.files ?? []).flatMap((item) => (item.path ? [item.path] : [])),
      );
      runtime.setState(next);
      runtime.persistState();
      return;
    }

    if (event.toolName === "file-create") {
      const details = event.details as FileCreateDetails | undefined;
      if (!details?.path) return;
      runtime.setState(pushTouchedFiles(runtime.getState(), [details.path]));
      runtime.persistState();
    }
  });

  pi.on("turn_end", async (_event, ctx: ExtensionContext) => {
    updateForgeUi(ctx, runtime.getState());
  });
}
