import type { ForgeState, Phase } from "./types.ts";

export function phasePrompt(state: ForgeState, phase: Phase): string {
  if (phase === "off") return "";

  if (phase === "tactic") {
    return [
      "[FORGE: TACTIC]",
      "You are in tactic mode.",
      "Goal: produce a small plan, not implementation.",
      "Rules:",
      "- Do not modify files.",
      "- Explore only enough to identify smallest useful next step.",
      "- State constraints, risk, and done-check.",
      "- If user asks for implementation, first frame smallest exert step.",
    ].join("\n");
  }

  if (phase === "exert") {
    return [
      "[FORGE: EXERT]",
      "You are in exert mode.",
      "Goal: make smallest complete forward patch.",
      "Rules:",
      "- Patch as soon as possible, not as big as possible.",
      "- Prefer localized edits, clear seams, readable names, nearby validation.",
      "- Assume human will intervene later in temper mode.",
      "- End with brief 'Best next human touch:' code location.",
    ].join("\n");
  }

  if (phase === "refine") {
    return [
      "[FORGE: REFINE]",
      "You are in refine mode.",
      "Goal: repair observed failures with minimal scope.",
      "Rules:",
      "- Focus on what fails now.",
      "- Separate conceptual flaws from mechanical breakage.",
      "- Do not expand into unrelated cleanup.",
      "- End with remaining open risks if any.",
    ].join("\n");
  }

  const touched =
    state.touchedFiles.length > 0
      ? state.touchedFiles.map((path) => `- ${path}`).join("\n")
      : "- none recorded yet";
  return [
    "[FORGE: TEMPER]",
    "You are in temper mode.",
    "Human must edit code. You are coach, reviewer, and assessor.",
    "Rules:",
    "- Do not modify files.",
    "- Start each turn by rereading touched files before judging current state.",
    "- Give exactly one meaningful codebase task for human to implement.",
    "- Prefer questions, hints, constraints, and what-to-notice over full solutions.",
    "- After human changes, reread files again, assess what improved, what still risks, and decide next task or re-scope.",
    "Touched files to reread first:",
    touched,
  ].join("\n");
}
