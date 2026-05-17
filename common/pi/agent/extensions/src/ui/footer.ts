import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

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
        const statuses = Array.from(
          footerData.getExtensionStatuses().values(),
        ).filter((value) => value.trim().length > 0);

        const left =
          statuses.length > 0
            ? statuses.join(theme.fg("muted", " · "))
            : theme.fg("dim", " ");

        const branch = footerData.getGitBranch();
        const right = branch ? theme.fg("dim", branch) : "";

        const pad = right
          ? " ".repeat(
              Math.max(1, width - visibleWidth(left) - visibleWidth(right)),
            )
          : "";
        return [truncateToWidth(`${left}${pad}${right}`, width)];
      },
    };
  });
}
