import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import registerCodeToolsFeature from "../features/code-tools/index.ts";
import registerContextMaskFeature from "../features/context-mask/index.ts";
import registerCwdFeature from "../features/cwd/index.ts";
import registerFocusBorderFeature from "../features/focus-border/index.ts";
import registerHashlineEditFeature from "../features/hashline-edit/index.ts";
import registerNuBlockFeature from "../features/nu-block/index.ts";
import registerSessionNameFeature from "../features/session-name/index.ts";
import registerToolPolicyFeature from "../features/tool-policy/index.ts";
import registerWebDocsFeature from "../features/web-docs/index.ts";

type FeatureRegistrar = (pi: ExtensionAPI) => void;

const FEATURES: FeatureRegistrar[] = [
  registerCodeToolsFeature,
  registerContextMaskFeature,
  registerCwdFeature,
  registerFocusBorderFeature,
  registerHashlineEditFeature,
  registerNuBlockFeature,
  registerSessionNameFeature,
  registerToolPolicyFeature,
  registerWebDocsFeature,
];

export function registerAppFeatures(pi: ExtensionAPI): void {
  for (const registerFeature of FEATURES) registerFeature(pi);
}
