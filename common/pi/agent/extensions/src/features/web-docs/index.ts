import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerWebDocsCommands } from "./commands.ts";
import { registerWebDocsTools } from "./tools.ts";

export default function registerWebDocsFeature(pi: ExtensionAPI): void {
  registerWebDocsCommands(pi);
  registerWebDocsTools(pi);
}
