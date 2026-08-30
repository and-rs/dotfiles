import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerCodeTools } from "./tools.ts";

export default function registerCodeToolsFeature(pi: ExtensionAPI): void {
  registerCodeTools(pi);
}
