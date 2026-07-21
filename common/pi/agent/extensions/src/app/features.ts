import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import registerCodeToolsFeature from "../features/code-tools/index.ts";
import registerCodeViewFeature from "../features/code-view/index.ts";
import registerQuickfixHandoffFeature from "../features/quickfix-handoff/index.ts";
import registerFocusBorderFeature from "../features/focus-border/index.ts";
import registerReadImageFeature from "../features/read-image/index.ts";
import registerWebDocsFeature from "../features/web-docs/index.ts";
import registerSidecarCommand from "../features/sidecar/index.ts";

type FeatureRegistrar = (pi: ExtensionAPI) => void;

const FEATURES: FeatureRegistrar[] = [
  registerSidecarCommand,
  registerCodeToolsFeature,
  registerCodeViewFeature,
  registerQuickfixHandoffFeature,
  registerFocusBorderFeature,
  registerReadImageFeature,
  registerWebDocsFeature,
];

export function registerAppFeatures(pi: ExtensionAPI): void {
  for (const registerFeature of FEATURES) registerFeature(pi);
}
