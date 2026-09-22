import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerWebDocsCommands } from "./commands.ts";
import { returnRawWebTools } from "./tools.ts";

export default function registerWebDocsFeature(pi: ExtensionAPI): void {
  registerWebDocsCommands(pi);
  for (const tool of returnRawWebTools()) pi.registerTool(tool);
}
