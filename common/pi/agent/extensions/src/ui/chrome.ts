import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

type ForgePhaseColor = "accent" | "warning" | "error" | "success" | "dim";

type ForgeChromeState = {
  phase: string;
  glyph: string;
  summary: string;
  color: ForgePhaseColor;
  lines?: string[];
};

const STATUS_ID = "forge-phase";
const WIDGET_ID = "forge-widget";

export function clearForgeChrome(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;
  ctx.ui.setStatus(STATUS_ID, undefined);
  ctx.ui.setWidget(WIDGET_ID, undefined, { placement: "belowEditor" });
}

export function renderForgeChrome(ctx: ExtensionContext, state: ForgeChromeState): void {
  if (!ctx.hasUI) return;
  const theme = ctx.ui.theme;
  const chip = theme.bg(
    "selectedBg",
    theme.fg(state.color, ` ${state.glyph} ${state.phase} `),
  );
  const suffix = theme.fg("dim", ` ${state.summary}`);
  ctx.ui.setStatus(STATUS_ID, `${chip}${suffix}`);
  if (state.lines && state.lines.length > 0) {
    ctx.ui.setWidget(WIDGET_ID, state.lines, { placement: "belowEditor" });
  }
}
