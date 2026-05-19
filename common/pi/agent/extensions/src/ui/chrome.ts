import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type ThemeColor =
  | "accent"
  | "warning"
  | "error"
  | "success"
  | "dim"
  | "muted"
  | "thinkingOff"
  | "thinkingMinimal"
  | "thinkingLow"
  | "thinkingMedium"
  | "thinkingHigh"
  | "thinkingXhigh";

type ForgePhaseColor = "accent" | "warning" | "error" | "success" | "dim";

type ForgeChromeState = {
  phase: string;
  glyph: string;
  summary: string;
  color: ForgePhaseColor;
  lines?: string[];
};

type FooterStats = {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  cost: number;
};

const MODEL_STATUS_ID = "session-model";
const THINKING_STATUS_ID = "session-thinking";
const CONTEXT_STATUS_ID = "session-context";
const FORGE_STATUS_ID = "forge-phase";
const FORGE_WIDGET_ID = "forge-widget";

const INTERNAL_STATUS_IDS = new Set([
  MODEL_STATUS_ID,
  THINKING_STATUS_ID,
  CONTEXT_STATUS_ID,
]);

function formatCount(value: number | null | undefined): string {
  if (value == null) return "?";
  if (value < 1000) return `${value}`;
  if (value < 10_000) return `${(value / 1000).toFixed(1)}k`;
  if (value < 1_000_000) return `${Math.round(value / 1000)}k`;
  if (value < 10_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  return `${Math.round(value / 1_000_000)}M`;
}

function formatCost(value: number): string {
  return `$${value.toFixed(3)}`;
}

function sanitizeSingleLine(text: string): string {
  return text
    .replace(/[\r\n\t]/g, " ")
    .replace(/ +/g, " ")
    .trim();
}

function toThinkingColor(level: string): ThemeColor {
  switch (level) {
    case "off":
      return "thinkingOff";
    case "minimal":
      return "thinkingMinimal";
    case "low":
      return "thinkingLow";
    case "medium":
      return "thinkingMedium";
    case "high":
      return "thinkingHigh";
    case "xhigh":
      return "thinkingXhigh";
    default:
      return "dim";
  }
}

function fitLine(text: string, width: number, ellipsis = "..."): string {
  return truncateToWidth(text, width, ellipsis);
}

function joinLeftRight(
  left: string,
  right: string,
  width: number,
  minGap = 1,
): string {
  const leftWidth = visibleWidth(left);
  const rightWidth = visibleWidth(right);

  // Left/right placement rule:
  // - if both fit, push right text flush against right edge
  // - if not, preserve left and clip right first
  if (!right) return fitLine(left, width);
  if (leftWidth + minGap + rightWidth <= width) {
    const gap = " ".repeat(width - leftWidth - rightWidth);
    return fitLine(`${left}${gap}${right}`, width);
  }

  const rightBudget = Math.max(0, width - leftWidth - minGap);
  if (rightBudget <= 0) return fitLine(left, width);

  const clippedRight = fitLine(right, rightBudget, "");
  const gap = " ".repeat(
    Math.max(minGap, width - leftWidth - visibleWidth(clippedRight)),
  );
  return fitLine(`${left}${gap}${clippedRight}`, width);
}

function chip(
  theme: ExtensionContext["ui"]["theme"],
  fg: ThemeColor,
  bg: "selectedBg",
  text: string,
): string {
  // Foreground + background together:
  // theme.bg("selectedBg", theme.fg("accent", " text "))
  return theme.bg(bg, theme.fg(fg, ` ${text} `));
}

function getThinkingLevel(ctx: ExtensionContext): string {
  // ExtensionContext does not expose direct ctx.getThinkingLevel().
  // Session history does expose thinking_level_change entries, so derive from there.
  const entries = ctx.sessionManager.getEntries();
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index];
    if (entry?.type === "thinking_level_change") return entry.thinkingLevel;
  }
  return "off";
}

function collectFooterStats(ctx: ExtensionContext): FooterStats {
  const totals: FooterStats = {
    input: 0,
    output: 0,
    cacheRead: 0,
    cacheWrite: 0,
    cost: 0,
  };

  // Built-in footer uses full session history, not only visible branch messages.
  // That keeps lifetime totals stable and survives compaction.
  for (const entry of ctx.sessionManager.getEntries()) {
    if (entry.type !== "message" || entry.message.role !== "assistant")
      continue;
    const message = entry.message as AssistantMessage;
    totals.input += message.usage.input;
    totals.output += message.usage.output;
    totals.cacheRead += message.usage.cacheRead;
    totals.cacheWrite += message.usage.cacheWrite;
    totals.cost += message.usage.cost.total;
  }

  return totals;
}

function buildLocationLine(
  ctx: ExtensionContext,
  theme: ExtensionContext["ui"]["theme"],
  branch: string | null,
  width: number,
): string {
  // Footer `render()` returns string[]. Each string is one line.
  // Need blank line? Push "". Need 3-line footer? Return 3 strings.
  let location = ctx.sessionManager.getCwd();
  const home = process.env.HOME || process.env.USERPROFILE;
  if (home && location.startsWith(home))
    location = `~${location.slice(home.length)}`;
  if (branch) location = `${location} (${branch})`;

  const sessionName = ctx.sessionManager.getSessionName();
  if (sessionName) location = `${location} • ${sessionName}`;

  return fitLine(theme.fg("dim", location), width, theme.fg("dim", "..."));
}

function buildStatsLeft(
  ctx: ExtensionContext,
  theme: ExtensionContext["ui"]["theme"],
): string {
  const totals = collectFooterStats(ctx);
  const contextUsage = ctx.getContextUsage();
  const contextWindow =
    contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
  const contextPercentValue = contextUsage?.percent ?? 0;
  const contextPercent =
    contextUsage?.percent == null ? "?" : `${contextUsage.percent.toFixed(1)}%`;

  const parts: string[] = [];
  if (totals.input) parts.push(`↑${formatCount(totals.input)}`);
  if (totals.output) parts.push(`↓${formatCount(totals.output)}`);
  if (totals.cacheRead) parts.push(`R${formatCount(totals.cacheRead)}`);
  if (totals.cacheWrite) parts.push(`W${formatCount(totals.cacheWrite)}`);
  if (totals.cost) parts.push(formatCost(totals.cost));

  // Context pressure deserves its own color, same spirit as built-in footer.
  const contextDisplay = `${contextPercent}/${formatCount(contextWindow)}`;
  if (contextUsage?.percent == null) {
    parts.push(theme.fg("dim", contextDisplay));
  } else if (contextPercentValue > 90) {
    parts.push(theme.fg("error", contextDisplay));
  } else if (contextPercentValue > 70) {
    parts.push(theme.fg("warning", contextDisplay));
  } else {
    parts.push(contextDisplay);
  }

  return theme.fg("dim", parts.join(" "));
}

function buildStatsRight(
  ctx: ExtensionContext,
  theme: ExtensionContext["ui"]["theme"],
  providerCount: number,
): string {
  const modelName = ctx.model?.id ?? "no-model";
  const reasoningEnabled = Boolean(ctx.model?.reasoning);
  const thinkingLevel = getThinkingLevel(ctx);

  const labelParts: string[] = [];
  if (providerCount > 1 && ctx.model?.provider)
    labelParts.push(`(${ctx.model.provider})`);
  labelParts.push(modelName);

  const base = theme.fg("dim", labelParts.join(" "));
  if (!reasoningEnabled) return base;

  const thinkingLabel =
    thinkingLevel === "off" ? "thinking off" : `thinking ${thinkingLevel}`;
  return `${base}${theme.fg("dim", " • ")}${theme.fg(toThinkingColor(thinkingLevel), thinkingLabel)}`;
}

function buildExtensionStatusLine(
  theme: ExtensionContext["ui"]["theme"],
  statuses: ReadonlyMap<string, string>,
  width: number,
): string | null {
  // Session model/thinking/context already have dedicated layout above.
  // Keep line for feature-owned statuses like forge and future widgets.
  const items = Array.from(statuses.entries())
    .filter(
      ([id, text]) => !INTERNAL_STATUS_IDS.has(id) && text.trim().length > 0,
    )
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([, text]) => sanitizeSingleLine(text));

  if (items.length === 0) return null;
  return fitLine(
    items.join(theme.fg("muted", " · ")),
    width,
    theme.fg("dim", "..."),
  );
}

export function installChromeFooter(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;

  ctx.ui.setFooter((tui, theme, footerData) => {
    const unsubBranch = footerData.onBranchChange(() => tui.requestRender());

    return {
      dispose: () => {
        unsubBranch();
      },
      invalidate() {},
      render(width: number): string[] {
        // Mini design system for this footer:
        // - line 1 = location metadata
        // - line 2 = measured stats on left, model identity on right
        // - line 3 = extension statuses
        //
        // Add padding with literal spaces.
        // Add new lines by returning more array entries.
        // Put content on L/R with joinLeftRight().
        const branch = footerData.getGitBranch();
        const lines = [
          buildLocationLine(ctx, theme, branch, width),
          joinLeftRight(
            buildStatsLeft(ctx, theme),
            buildStatsRight(ctx, theme, footerData.getAvailableProviderCount()),
            width,
            2,
          ),
        ];

        const statusLine = buildExtensionStatusLine(
          theme,
          footerData.getExtensionStatuses(),
          width,
        );
        if (statusLine) lines.push(statusLine);
        return lines;
      },
    };
  });
}

export function renderModelStatus(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;
  const text = ctx.model?.id ?? "no-model";
  ctx.ui.setStatus(MODEL_STATUS_ID, ctx.ui.theme.fg("dim", `model: ${text}`));
}

export function renderThinkingStatus(
  ctx: ExtensionContext,
  level = "default",
): void {
  if (!ctx.hasUI) return;
  ctx.ui.setStatus(
    THINKING_STATUS_ID,
    ctx.ui.theme.fg(toThinkingColor(level), `thinking: ${level}`),
  );
}

export function renderContextStatus(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;
  const usage = ctx.getContextUsage();
  if (!usage) {
    ctx.ui.setStatus(CONTEXT_STATUS_ID, ctx.ui.theme.fg("dim", "ctx: ?"));
    return;
  }

  const percent = usage.percent == null ? "?" : `${Math.round(usage.percent)}%`;
  const tokens = formatCount(usage.tokens);
  ctx.ui.setStatus(
    CONTEXT_STATUS_ID,
    ctx.ui.theme.fg("dim", `ctx: ${tokens}/${percent}`),
  );
}

export function clearForgeChrome(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;
  ctx.ui.setStatus(FORGE_STATUS_ID, undefined);
  ctx.ui.setWidget(FORGE_WIDGET_ID, undefined, { placement: "belowEditor" });
}

export function renderForgeChrome(
  ctx: ExtensionContext,
  state: ForgeChromeState,
): void {
  if (!ctx.hasUI) return;

  const themedChip = chip(
    ctx.ui.theme,
    state.color,
    "selectedBg",
    `${state.glyph} ${state.phase}`,
  );
  const suffix = ctx.ui.theme.fg("dim", ` ${state.summary}`);
  ctx.ui.setStatus(FORGE_STATUS_ID, `${themedChip}${suffix}`);

  // Widgets also use string[]. One element = one visual line.
  // Want horizontal padding? Add spaces inside each string yourself.
  if (state.lines && state.lines.length > 0) {
    ctx.ui.setWidget(FORGE_WIDGET_ID, state.lines, {
      placement: "belowEditor",
    });
    return;
  }

  ctx.ui.setWidget(FORGE_WIDGET_ID, undefined, { placement: "belowEditor" });
}

