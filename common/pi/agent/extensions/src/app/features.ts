import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import registerAnchorlineFeature from "../features/anchorline/index.ts";
import registerCodeToolsFeature from "../features/code-tools/index.ts";
import registerContextMaskFeature from "../features/context-mask/index.ts";
import registerCwdFeature from "../features/cwd/index.ts";
import registerFileCreateFeature from "../features/file-create/index.ts";
import registerFocusBorderFeature from "../features/focus-border/index.ts";
import registerNuBlockFeature from "../features/nu-block/index.ts";
import registerReadImageFeature from "../features/read-image/index.ts";
import registerSessionNameFeature from "../features/session-name/index.ts";
import registerToolPolicyFeature from "../features/tool-policy/index.ts";
import registerWebDocsFeature from "../features/web-docs/index.ts";

type FeatureRegistrar = (pi: ExtensionAPI) => void;

const FEATURES: FeatureRegistrar[] = [
  registerAnchorlineFeature,
  registerCodeToolsFeature,
  registerContextMaskFeature,
  registerCwdFeature,
  registerFileCreateFeature,
  registerFocusBorderFeature,
  registerReadImageFeature,
  registerNuBlockFeature,
  registerSessionNameFeature,
  registerToolPolicyFeature,
  registerWebDocsFeature,
];

export function registerAppFeatures(pi: ExtensionAPI): void {
  for (const registerFeature of FEATURES) registerFeature(pi);
}
