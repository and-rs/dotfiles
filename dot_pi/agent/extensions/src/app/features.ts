import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import registerQuickfix from "../features/quickfix/index.ts";
import registerReadImageFeature from "../features/read-image/index.ts";
import registerSidecarCommand from "../features/sidecar/index.ts";
import registerWebDocsFeature from "../features/web-docs/index.ts";
import registerEditorEvents from "../ui/editor/editor.ts";
import registerAppUi from "../ui/osd.ts";

type FeatureRegistrar = (pi: ExtensionAPI) => void;

const FEATURES: FeatureRegistrar[] = [
  registerSidecarCommand,
  registerEditorEvents,
  registerAppUi,
  registerReadImageFeature,
  registerQuickfix,
  registerWebDocsFeature,
];

export function registerAppFeatures(pi: ExtensionAPI): void {
  for (const registerFeature of FEATURES) registerFeature(pi);
}
