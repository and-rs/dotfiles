import type { ForgeState, Phase } from "./types.ts";

export const FORGE_STATE_TYPE = "forge-state";
const MAX_TOUCHED_FILES = 12;
const PHASE_ORDER: Phase[] = ["tactic", "exert", "refine", "temper"];

export function createForgeState(): ForgeState {
  return {
    phase: "off",
    touchedFiles: [],
  };
}

export function isForged(state: ForgeState): boolean {
  return state.phase !== "off";
}

export function isReadOnlyPhase(phase: Phase): boolean {
  return phase === "tactic" || phase === "temper";
}

export function normalizePhase(raw: string): Phase | null {
  const value = raw.trim().toLowerCase();
  if (
    value === "off" ||
    value === "tactic" ||
    value === "exert" ||
    value === "refine" ||
    value === "temper"
  ) {
    return value;
  }
  return null;
}

export function nextPhase(current: Phase): Phase {
  if (current === "off") return "tactic";
  const index = PHASE_ORDER.indexOf(current);
  if (index === -1 || index === PHASE_ORDER.length - 1) return "tactic";
  return PHASE_ORDER[index + 1];
}

export function pushTouchedFiles(state: ForgeState, paths: string[]): ForgeState {
  const next = [...state.touchedFiles];
  for (const path of paths) {
    const trimmed = path.trim();
    if (!trimmed) continue;
    const withoutExisting = next.filter((entry) => entry !== trimmed);
    withoutExisting.push(trimmed);
    next.splice(0, next.length, ...withoutExisting.slice(-MAX_TOUCHED_FILES));
  }
  return {
    ...state,
    touchedFiles: next,
  };
}

export function restoreForgeState(data: Partial<ForgeState> | undefined): ForgeState {
  return {
    phase: data?.phase ?? "off",
    touchedFiles: Array.isArray(data?.touchedFiles) ? data!.touchedFiles : [],
  };
}
