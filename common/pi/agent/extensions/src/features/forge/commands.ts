import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { nextPhase, normalizePhase } from "./state.ts";
import type { ForgeState, Phase } from "./types.ts";
import { phaseGlyph, updateForgeUi } from "./ui.ts";

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

async function handlePhaseCommand(args: string, ctx: ExtensionContext, deps: ForgeCommandDeps): Promise<void> {
  const state = deps.getState();
  const raw = args.trim().toLowerCase();
  if (!raw || raw === "status") {
    if (state.phase === "off") {
      ctx.ui.notify("Forge off.", "info");
      return;
    }
    ctx.ui.notify(`Forge ${phaseGlyph(state.phase)} ${state.phase}.`, "info");
    return;
  }

  if (raw === "next") {
    await setPhase(ctx, nextPhase(state.phase), deps);
    return;
  }

  const phase = normalizePhase(raw);
  if (!phase) {
    ctx.ui.notify("Use /phase tactic|exert|refine|temper|off|next|status", "warning");
    return;
  }
  await setPhase(ctx, phase, deps);
}

export function registerForgeCommands(pi: ExtensionAPI, deps: ForgeCommandDeps): void {
  pi.registerCommand("forge", {
    description: "Enable forge flow and enter tactic mode",
    handler: async (_args, ctx) => setPhase(ctx, "tactic", deps),
  });

  pi.registerCommand("unforge", {
    description: "Disable forge flow",
    handler: async (_args, ctx) => setPhase(ctx, "off", deps),
  });

  pi.registerCommand("phase", {
    description: "Set forge phase: tactic, exert, refine, temper, off, next, status",
    handler: async (args, ctx) => handlePhaseCommand(args, ctx, deps),
  });

  for (const phase of ["tactic", "exert", "refine", "temper"] as const) {
    pi.registerCommand(phase, {
      description: `Set forge phase to ${phase}`,
      handler: async (_args, ctx) => setPhase(ctx, phase, deps),
    });
  }
}
