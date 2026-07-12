import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerAppFeatures } from "./features.ts";
import { registerReadOnlyProfile } from "./read-only-profile.ts";
import { registerAppUi } from "./ui.ts";

export default function registerApp(pi: ExtensionAPI): void {
  registerAppUi(pi);
  registerAppFeatures(pi);
  registerReadOnlyProfile(pi);
}
