import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import registerSecretGuard from "../features/secret-guard.ts";
import { registerAppFeatures } from "./features.ts";
import { registerModes } from "./modes.ts";

export default function registerApp(pi: ExtensionAPI): Promise<void> {
  const featuresReady = registerAppFeatures(pi);
  registerSecretGuard(pi);
  registerModes(pi);
  return featuresReady;
}
