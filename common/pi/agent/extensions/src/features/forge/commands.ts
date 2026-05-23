import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { nextPhase, normalizePhase } from "./state.ts";
import type { ForgeState, Phase } from "./types.ts";
import { phaseGlyph, updateForgeUi } from "./ui.ts";

const FORGE_PHASES = ["tactic", "exert", "refine", "temper"] as const;
const FORGE_ACTIONS = [...FORGE_PHASES, "off", "next", "status"] as const;

export type ForgeCommandDeps = {
  getState: () => ForgeState;
  setState: (state: ForgeState) => void;
  persistState: () => void;
  applyTools: () => void;
};

async function setPhase(ctx: ExtensionContext, phase: Phase, deps: ForgeCommandDeps): Promise<void> {
  deps.setState({
    ...deps.getState(),
    phase,
  });
  deps.applyTools();
  updateForgeUi(ctx, deps.getState());
  deps.persistState();
  if (phase === "off") {
    ctx.ui.notify("Forge off.", "info");
    return;
  }
  ctx.ui.notify(`Forge ${phaseGlyph(phase)} ${phase}.`, "info");
}

async function handleForgeCommand(args: string, ctx: ExtensionContext, deps: ForgeCommandDeps): Promise<void> {
  const state = deps.getState();
  let action = args.trim().toLowerCase();

  if (!action) {
    const choice = await ctx.ui.select("Forge", [...FORGE_PHASES]);
    if (!choice) {
      ctx.ui.notify("Cancelled", "info");
      return;
    }
    action = choice;
  }

  if (action === "status") {
    if (state.phase === "off") {
      ctx.ui.notify("Forge off.", "info");
      return;
    }
    ctx.ui.notify(`Forge ${phaseGlyph(state.phase)} ${state.phase}.`, "info");
    return;
  }

  if (action === "next") {
    await setPhase(ctx, nextPhase(state.phase), deps);
    return;
  }

  const phase = normalizePhase(action);
  if (!phase) {
    ctx.ui.notify("Usage: /forge [tactic|exert|refine|temper|off|next|status]", "warning");
    return;
  }

  await setPhase(ctx, phase, deps);
}

export function registerForgeCommands(pi: ExtensionAPI, deps: ForgeCommandDeps): void {
  pi.registerCommand("forge", {
    description: "Set forge mode: tactic, exert, refine, temper, off, next, status",
    getArgumentCompletions: (prefix) => {
      const value = prefix.trim().toLowerCase();
      return FORGE_ACTIONS.filter((item) => item.startsWith(value)).map((item) => ({ value: item, label: item }));
    },
    handler: async (args, ctx) => handleForgeCommand(args, ctx, deps),
  });
}