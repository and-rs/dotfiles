import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerHashlineEditTools } from "./tools.ts";

export default function registerHashlineEditFeature(pi: ExtensionAPI): void {
  registerHashlineEditTools(pi);
}
