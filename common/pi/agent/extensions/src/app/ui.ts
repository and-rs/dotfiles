import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { installChromeFooter } from "../ui/footer.ts";

export function registerAppUi(pi: ExtensionAPI): void {
  pi.on("session_start", async (_event, ctx) => {
    installChromeFooter(ctx);
  });
}
