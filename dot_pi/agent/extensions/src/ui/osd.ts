import { isAbsolute, relative, resolve, sep } from "node:path";
import type {
  ExtensionAPI,
  ExtensionContext,
  ReadonlyFooterDataProvider,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { getMode, type Mode, onModeChange } from "../app/modes.ts";

const INSET = 1;

const CHIP_COLOR: Record<Mode, "accent" | "error" | "warning"> = {
  plan: "accent",
  build: "error",
  teach: "warning",
};

function formatTokens(count: number): string {
  if (count < 1000) return count.toString();
  if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
  return `${Math.round(count / 1000000)}M`;
}

function formatCwdForFooter(cwd: string, home: string | undefined): string {
  if (!home) return cwd;
  const resolvedCwd = resolve(cwd);
  const resolvedHome = resolve(home);
  const relativeToHome = relative(resolvedHome, resolvedCwd);
  const isInsideHome =
    relativeToHome === "" ||
    (relativeToHome !== ".." &&
      !relativeToHome.startsWith(`..${sep}`) &&
      !isAbsolute(relativeToHome));
  if (!isInsideHome) return cwd;
  if (relativeToHome === "") return "~";
  return `~${sep}${relativeToHome}`;
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

function renderStockFooter(
  ctx: ExtensionContext,
  pi: ExtensionAPI,
  theme: Theme,
  footerData: ReadonlyFooterDataProvider,
  width: number,
): string[] {
  let totalInput = 0;
  let totalOutput = 0;
  let totalCacheRead = 0;
  let totalCacheWrite = 0;
  let totalCost = 0;
  let latestCacheHitRate: number | undefined;
  for (const entry of ctx.sessionManager.getEntries()) {
    if (entry.type !== "message" || entry.message.role !== "assistant") {
      continue;
    }
    totalInput += entry.message.usage.input;
    totalOutput += entry.message.usage.output;
    totalCacheRead += entry.message.usage.cacheRead;
    totalCacheWrite += entry.message.usage.cacheWrite;
    totalCost += entry.message.usage.cost.total;
    const promptTokens =
      entry.message.usage.input +
      entry.message.usage.cacheRead +
      entry.message.usage.cacheWrite;
    if (promptTokens > 0) {
      latestCacheHitRate = (entry.message.usage.cacheRead / promptTokens) * 100;
    }
  }

  const model = ctx.model;
  const contextUsage = ctx.getContextUsage();
  let contextWindow = 0;
  if (contextUsage?.contextWindow !== undefined) {
    contextWindow = contextUsage.contextWindow;
  } else if (model?.contextWindow !== undefined) {
    contextWindow = model.contextWindow;
  }
  let contextPercentValue = 0;
  if (contextUsage?.percent !== undefined && contextUsage.percent !== null) {
    contextPercentValue = contextUsage.percent;
  }
  let contextPercent = "?";
  if (contextUsage?.percent !== null) {
    contextPercent = contextPercentValue.toFixed(1);
  }

  let pwd = formatCwdForFooter(
    ctx.sessionManager.getCwd(),
    process.env.HOME ?? process.env.USERPROFILE,
  );
  const branch = footerData.getGitBranch();
  if (branch) pwd = `${pwd} (${branch})`;
  const sessionName = ctx.sessionManager.getSessionName();
  if (sessionName) pwd = `${pwd} • ${sessionName}`;

  const statsParts: string[] = [];
  if (totalInput) statsParts.push(`↑${formatTokens(totalInput)}`);
  if (totalOutput) statsParts.push(`↓${formatTokens(totalOutput)}`);
  if (totalCacheRead) statsParts.push(`R${formatTokens(totalCacheRead)}`);
  if (totalCacheWrite) statsParts.push(`W${formatTokens(totalCacheWrite)}`);
  if (
    (totalCacheRead > 0 || totalCacheWrite > 0) &&
    latestCacheHitRate !== undefined
  ) {
    statsParts.push(`CH${latestCacheHitRate.toFixed(1)}%`);
  }
  let usingOAuth = false;
  if (model) usingOAuth = ctx.modelRegistry.isUsingOAuth(model);
  if (totalCost || usingOAuth) {
    let subscriptionSuffix = "";
    if (usingOAuth) subscriptionSuffix = " (oauth)";
    statsParts.push(`$${totalCost.toFixed(3)}${subscriptionSuffix}`);
  }

  let contextPercentDisplay = `?/${formatTokens(contextWindow)}`;
  if (contextPercent !== "?") {
    contextPercentDisplay = `${contextPercent}%/${formatTokens(contextWindow)}`;
  }
  let contextPercentStr = contextPercentDisplay;
  if (contextPercentValue > 90) {
    contextPercentStr = theme.fg("error", contextPercentDisplay);
  } else if (contextPercentValue > 70) {
    contextPercentStr = theme.fg("warning", contextPercentDisplay);
  }
  statsParts.push(contextPercentStr);
  if (process.env.PI_EXPERIMENTAL === "1") {
    statsParts.push(
      `${theme.fg("dim", "•")} ${theme.bold(theme.fg("warning", "xp"))}`,
    );
  }

  let statsLeft = statsParts.join(" ");
  let statsLeftWidth = visibleWidth(statsLeft);
  if (statsLeftWidth > width) {
    statsLeft = truncateToWidth(statsLeft, width, "...");
    statsLeftWidth = visibleWidth(statsLeft);
  }

  let modelName = "no-model";
  if (model) modelName = model.id;
  let rightSideWithoutProvider = modelName;
  if (model?.reasoning) {
    const thinkingLevel = pi.getThinkingLevel();
    let thinkingText: string = thinkingLevel;
    if (thinkingLevel === "off") thinkingText = "thinking off";
    rightSideWithoutProvider = `${modelName} • ${thinkingText}`;
  }
  let rightSide = rightSideWithoutProvider;
  if (footerData.getAvailableProviderCount() > 1 && model) {
    rightSide = `(${model.provider}) ${rightSideWithoutProvider}`;
    if (statsLeftWidth + 2 + visibleWidth(rightSide) > width) {
      rightSide = rightSideWithoutProvider;
    }
  }
  const rightSideWidth = visibleWidth(rightSide);
  const availableForRight = width - statsLeftWidth - 2;
  let statsLine = statsLeft;
  if (statsLeftWidth + 2 + rightSideWidth <= width) {
    statsLine = `${statsLeft}${" ".repeat(width - statsLeftWidth - rightSideWidth)}${rightSide}`;
  } else if (availableForRight > 0) {
    const truncatedRight = truncateToWidth(rightSide, availableForRight, "");
    statsLine = `${statsLeft}${" ".repeat(Math.max(0, width - statsLeftWidth - visibleWidth(truncatedRight)))}${truncatedRight}`;
  }

  const dimStatsLeft = theme.fg("dim", statsLeft);
  const dimRemainder = theme.fg("dim", statsLine.slice(statsLeft.length));
  const lines = [
    truncateToWidth(theme.fg("dim", pwd), width, theme.fg("dim", "...")),
    dimStatsLeft + dimRemainder,
  ];
  const statuses = footerData.getExtensionStatuses();
  if (statuses.size > 0) {
    const statusLine = Array.from(statuses.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([, text]) =>
        text
          .replace(/[\r\n\t]/g, " ")
          .replace(/ +/g, " ")
          .trim(),
      )
      .join(" ");
    lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "...")));
  }
  return lines;
}

function withModeChip(lines: string[], inner: number, chip: string): string[] {
  if (inner <= 0) return lines;
  let chipText = chip;
  if (visibleWidth(chip) > inner) chipText = truncateToWidth(chip, inner);
  const chipWidth = visibleWidth(chipText);
  if (lines.length === 0) return [chipText];
  const pwd = lines[0];
  if (pwd === undefined) return [chipText];
  const rest = lines.slice(1);
  const gapMin = 1;
  const pwdBudget = Math.max(0, inner - chipWidth - gapMin);
  const pwdText = truncateToWidth(pwd, pwdBudget);
  const gap = Math.max(gapMin, inner - visibleWidth(pwdText) - chipWidth);
  return [`${pwdText}${" ".repeat(gap)}${chipText}`, ...rest];
}

function installChromeFooter(ctx: ExtensionContext, pi: ExtensionAPI): void {
  if (!ctx.hasUI) return;
  ctx.ui.setFooter((tui, theme, footerData) => {
    const unsubBranch = footerData.onBranchChange(() => tui.requestRender());
    const unsubMode = onModeChange(() => tui.requestRender());
    return {
      dispose: () => {
        unsubBranch();
        unsubMode();
      },
      invalidate() {
        // Footer data is read on every render.
      },
      render(width: number) {
        let inset = 0;
        if (width >= INSET * 2) inset = INSET;
        const inner = Math.max(0, width - inset * 2);
        const mode = getMode();
        const thinkingLevel = pi.getThinkingLevel();
        let thinkingText: string = thinkingLevel;
        if (thinkingLevel === "off") thinkingText = "thinking off";
        const colorThinking = theme.getThinkingBorderColor(thinkingLevel);
        const lines = renderStockFooter(ctx, pi, theme, footerData, inner).map(
          (line) => line.replace(thinkingText, colorThinking(thinkingText)),
        );
        const chip = theme.inverse(
          theme.fg(CHIP_COLOR[mode], theme.bold(` ${mode} `)),
        );
        return padLines(withModeChip(lines, inner, chip), width, inset);
      },
    };
  });
}

export default function registerAppUi(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    installChromeFooter(ctx, pi);
  });
  pi.on("session_shutdown", (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setFooter(undefined);
  });
}
