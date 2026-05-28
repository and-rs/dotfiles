import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerNuBlockTools } from "./tools.ts";

export default function registerNuBlockFeature(pi: ExtensionAPI): void {
  registerNuBlockTools(pi);
}
