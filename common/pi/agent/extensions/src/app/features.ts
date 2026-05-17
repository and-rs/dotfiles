import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import registerCheckpointFeature from "../features/checkpoint/index.ts";
import registerCodeToolsFeature from "../features/code-tools/index.ts";
import registerContextMaskFeature from "../features/context-mask/index.ts";
import registerFocusBorderFeature from "../features/focus-border/index.ts";
import registerForgeFeature from "../features/forge/index.ts";
import registerHashlineEditFeature from "../features/hashline-edit/index.ts";
import registerToolPolicyFeature from "../features/tool-policy/index.ts";
import registerWebDocsFeature from "../features/web-docs/index.ts";

type FeatureRegistrar = (pi: ExtensionAPI) => void;

const FEATURES: FeatureRegistrar[] = [
  registerCodeToolsFeature,
  registerContextMaskFeature,
  registerFocusBorderFeature,
  registerForgeFeature,
  registerHashlineEditFeature,
  registerCheckpointFeature,
  registerToolPolicyFeature,
  registerWebDocsFeature,
];

export function registerAppFeatures(pi: ExtensionAPI): void {
  for (const registerFeature of FEATURES) registerFeature(pi);
}
