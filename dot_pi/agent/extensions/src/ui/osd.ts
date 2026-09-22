import {
  type AgentSession,
  type ExtensionAPI,
  type ExtensionContext,
  FooterComponent,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { getMode, onModeChange, type Mode } from "../app/modes.ts";

const INSET = 1;

const CHIP_COLOR: Record<Mode, "accent" | "error" | "warning"> = {
  plan: "accent",
  build: "error",
  teach: "warning",
};

function stockSession(ctx: ExtensionContext): AgentSession {
  return {
    get state() {
      return { model: ctx.model, thinkingLevel: ctx.thinkingLevel };
    },
    get sessionManager() {
      return ctx.sessionManager;
    },
    getContextUsage: () => ctx.getContextUsage(),
    modelRuntime: {
      isUsingOAuth: () => false,
      isUsingSubscription: () => false,
    },
  } as unknown as AgentSession;
}

function padLines(lines: string[], width: number, inset: number): string[] {
  const inner = Math.max(0, width - inset * 2);
  const left = " ".repeat(inset);
  return lines.map((line) => {
    const text = truncateToWidth(line, inner);
    const right = " ".repeat(Math.max(0, inner - visibleWidth(text)) + inset);
    return `${left}${text}${right}`;
  });
}

function withModeChip(
  lines: string[],
  inner: number,
  chip: string,
): string[] {
  if (inner <= 0) return lines;
  const chipText =
    visibleWidth(chip) > inner ? truncateToWidth(chip, inner) : chip;
  const chipWidth = visibleWidth(chipText);
  if (lines.length === 0) return [chipText];
  const [pwd, ...rest] = lines;
  const gapMin = 1;
  const pwdBudget = Math.max(0, inner - chipWidth - gapMin);
  const pwdText = truncateToWidth(pwd, pwdBudget);
  const gap = Math.max(gapMin, inner - visibleWidth(pwdText) - chipWidth);
  return [`${pwdText}${" ".repeat(gap)}${chipText}`, ...rest];
}

function installChromeFooter(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;
  ctx.ui.setFooter((tui, theme, footerData) => {
    const stock = new FooterComponent(stockSession(ctx), footerData);
    const unsubBranch = footerData.onBranchChange(() => tui.requestRender());
    const unsubMode = onModeChange(() => tui.requestRender());
    return {
      dispose: () => {
        unsubBranch();
        unsubMode();
        stock.dispose();
      },
      invalidate() {
        stock.invalidate();
      },
      render(width: number) {
        const inset = width >= INSET * 2 ? INSET : 0;
        const inner = Math.max(0, width - inset * 2);
        const mode = getMode();
        const chip = theme.inverse(theme.fg(CHIP_COLOR[mode], theme.bold(` ${mode} `)));
        return padLines(
          withModeChip(stock.render(inner), inner, chip),
          width,
          inset,
        );
      },
    };
  });
}

export default function registerAppUi(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    installChromeFooter(ctx);
  });
  pi.on("session_shutdown", (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setFooter(undefined);
  });
}
