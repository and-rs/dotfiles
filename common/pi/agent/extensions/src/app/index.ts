import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerAppFeatures } from "./features.ts";
import { registerAppUi } from "./ui.ts";

export default function registerApp(pi: ExtensionAPI): void {
  registerAppUi(pi);
  registerAppFeatures(pi);
}
