import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { clearForgeChrome, renderForgeChrome } from "../../ui/chrome.ts";
import type { ForgeState, Phase } from "./types.ts";

export function phaseColor(
  phase: Phase,
): "accent" | "warning" | "error" | "success" | "dim" {
  switch (phase) {
    case "tactic":
      return "accent";
    case "exert":
      return "warning";
    case "refine":
      return "error";
    case "temper":
      return "success";
    default:
      return "dim";
  }
}

export function phaseGlyph(phase: Phase): string {
  switch (phase) {
    case "tactic":
      return "τ";
    case "exert":
      return "ε";
    case "refine":
      return "ρ";
    case "temper":
      return "θ";
    default:
      return "·";
  }
}

export function phaseSummary(phase: Phase): string {
  switch (phase) {
    case "tactic":
      return "small tactic only";
    case "exert":
      return "smallest complete patch";
    case "refine":
      return "repair failures only";
    case "temper":
      return "human edits, agent coaches";
    default:
      return "";
  }
}

export function updateForgeUi(ctx: ExtensionContext, state: ForgeState): void {
  if (!ctx.hasUI || state.phase === "off") {
    clearForgeChrome(ctx);
    return;
  }

  renderForgeChrome(ctx, {
    phase: state.phase,
    glyph: phaseGlyph(state.phase),
    summary: phaseSummary(state.phase),
    color: phaseColor(state.phase),
  });
}
