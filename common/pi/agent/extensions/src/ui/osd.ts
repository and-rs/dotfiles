import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

function installChromeFooter(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;
  ctx.ui.setFooter((tui, _, footerData) => {
    const unsubBranch = footerData.onBranchChange(() => tui.requestRender());
    return {
      dispose: () => {
        unsubBranch();
      },
      invalidate() {},
      render() {
        return [""];
      },
    };
  });
}

export function registerAppUi(pi: ExtensionAPI): void {
  pi.on("session_start", async (_event, ctx) => {
    installChromeFooter(ctx);
  });
}
