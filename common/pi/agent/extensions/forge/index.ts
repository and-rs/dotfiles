import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

type Phase = "off" | "tactic" | "exert" | "refine" | "temper";

type ForgeState = {
  phase: Phase;
  touchedFiles: string[];
};

type HashlineEditDetails = {
  files?: Array<{
    path?: string;
  }>;
};

type FileCreateDetails = {
  path?: string;
};

const STATE_TYPE = "forge-state";
const STATUS_ID = "forge-phase";
const WIDGET_ID = "forge-widget";
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
const TACTIC_OR_TEMPER_WRITE_RE =
  /\b(rm|mv|cp|mkdir|touch|chmod|chown|ln|install|dd)\b|\b(sed|perl)\s+-i\b|\btee\b|>>|[^|]>|\bgit\s+(add|commit|reset|checkout|switch|restore|clean|apply|am|rebase|merge|cherry-pick|push|pull)\b|\bstash\s+(apply|pop|drop|clear)\b|\b(npm|pnpm|yarn|bun)\s+(add|install|update|remove|unlink)\b|\bpip\s+install\b|\bcargo\s+(add|install)\b/i;

const PHASE_ORDER: Phase[] = ["tactic", "exert", "refine", "temper"];

export default function forgeExtension(pi: ExtensionAPI): void {
  let state: ForgeState = {
    phase: "off",
    touchedFiles: [],
  };

  function isForged(): boolean {
    return state.phase !== "off";
  }

  function isReadOnlyPhase(phase: Phase): boolean {
    return phase === "tactic" || phase === "temper";
  }

  function normalizePhase(raw: string): Phase | null {
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

  function nextPhase(current: Phase): Phase {
    if (current === "off") return "tactic";
    const index = PHASE_ORDER.indexOf(current);
    if (index === -1 || index === PHASE_ORDER.length - 1) return "tactic";
    return PHASE_ORDER[index + 1];
  }

  function pushTouchedFiles(paths: string[]): void {
    const next = [...state.touchedFiles];
    for (const path of paths) {
      const trimmed = path.trim();
      if (!trimmed) continue;
      const withoutExisting = next.filter((entry) => entry !== trimmed);
      withoutExisting.push(trimmed);
      next.splice(0, next.length, ...withoutExisting.slice(-12));
    }
    state.touchedFiles = next;
  }

  function phaseColor(
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

  function phaseGlyph(phase: Phase): string {
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

  function phaseSummary(phase: Phase): string {
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

  function applyTools(): void {
    pi.setActiveTools(
      isReadOnlyPhase(state.phase) ? READ_ONLY_TOOLS : FULL_TOOLS,
    );
  }

  function persistState(): void {
    pi.appendEntry(STATE_TYPE, state);
  }

  function updateUi(ctx: ExtensionContext): void {
    if (!ctx.hasUI || state.phase === "off") {
      ctx.ui.setStatus(STATUS_ID, undefined);
      ctx.ui.setWidget(WIDGET_ID, undefined, { placement: "belowEditor" });
      return;
    }

    const theme = ctx.ui.theme;
    const chip = theme.bg(
      "selectedBg",
      theme.fg(
        phaseColor(state.phase),
        ` ${phaseGlyph(state.phase)} ${state.phase} `,
      ),
    );
    const suffix = theme.fg("dim", ` ${phaseSummary(state.phase)}`);
    ctx.ui.setStatus(STATUS_ID, `${chip}${suffix}`);
  }

  function phasePrompt(phase: Phase): string {
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

  async function setPhase(ctx: ExtensionContext, phase: Phase): Promise<void> {
    state.phase = phase;
    applyTools();
    updateUi(ctx);
    persistState();
    if (phase === "off") {
      ctx.ui.notify("Forge off.", "info");
      return;
    }
    ctx.ui.notify(`Forge ${phaseGlyph(phase)} ${phase}.`, "info");
  }

  async function handlePhaseCommand(
    args: string,
    ctx: ExtensionContext,
  ): Promise<void> {
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
      await setPhase(ctx, nextPhase(state.phase));
      return;
    }

    const phase = normalizePhase(raw);
    if (!phase) {
      ctx.ui.notify(
        "Use /phase tactic|exert|refine|temper|off|next|status",
        "warning",
      );
      return;
    }
    await setPhase(ctx, phase);
  }

  pi.registerCommand("forge", {
    description: "Enable forge flow and enter tactic mode",
    handler: async (_args, ctx) => setPhase(ctx, "tactic"),
  });

  pi.registerCommand("unforge", {
    description: "Disable forge flow",
    handler: async (_args, ctx) => setPhase(ctx, "off"),
  });

  pi.registerCommand("phase", {
    description:
      "Set forge phase: tactic, exert, refine, temper, off, next, status",
    handler: async (args, ctx) => handlePhaseCommand(args, ctx),
  });

  for (const phase of PHASE_ORDER) {
    pi.registerCommand(phase, {
      description: `Set forge phase to ${phase}`,
      handler: async (_args, ctx) => setPhase(ctx, phase),
    });
  }

  pi.on("session_start", async (_event, ctx) => {
    const entry = ctx.sessionManager
      .getEntries()
      .filter(
        (item: { type: string; customType?: string }) =>
          item.type === "custom" && item.customType === STATE_TYPE,
      )
      .pop() as { data?: ForgeState } | undefined;

    if (entry?.data) {
      state = {
        phase: entry.data.phase ?? "off",
        touchedFiles: Array.isArray(entry.data.touchedFiles)
          ? entry.data.touchedFiles
          : [],
      };
    }

    applyTools();
    updateUi(ctx);
  });

  pi.on("before_agent_start", async (event) => {
    if (!isForged()) return;
    return {
      systemPrompt: `${event.systemPrompt}\n\n${phasePrompt(state.phase)}`,
    };
  });

  pi.on("tool_call", (event) => {
    if (!isReadOnlyPhase(state.phase)) return;
    if (
      event.toolName === "hashline-edit" ||
      event.toolName === "file-create"
    ) {
      return {
        block: true,
        reason: `${state.phase} mode is read-only. Move to /phase exert or /phase refine for edits.`,
      };
    }
    if (event.toolName !== "bash") return;
    const command =
      typeof event.input.command === "string" ? event.input.command : "";
    if (!TACTIC_OR_TEMPER_WRITE_RE.test(command)) return;
    return {
      block: true,
      reason: `${state.phase} mode blocks write-like bash. Keep this phase read-only.`,
    };
  });

  pi.on("tool_result", async (event) => {
    if (event.toolName === "hashline-edit") {
      const details = event.details as HashlineEditDetails | undefined;
      pushTouchedFiles(
        (details?.files ?? []).flatMap((item) =>
          item.path ? [item.path] : [],
        ),
      );
      persistState();
      return;
    }
    if (event.toolName === "file-create") {
      const details = event.details as FileCreateDetails | undefined;
      if (details?.path) {
        pushTouchedFiles([details.path]);
        persistState();
      }
    }
  });

  pi.on("turn_end", async (_event, ctx) => {
    updateUi(ctx);
  });
}
