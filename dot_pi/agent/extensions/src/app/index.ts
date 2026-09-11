import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerAppFeatures } from "./features.ts";
import { registerModes } from "./modes.ts";

export default function registerApp(pi: ExtensionAPI): void {
  registerAppFeatures(pi);
  registerModes(pi);
}
