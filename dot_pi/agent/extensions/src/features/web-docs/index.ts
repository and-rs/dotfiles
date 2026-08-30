import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerWebDocsCommands } from "./commands.ts";
import { returnRawWebTools } from "./tools.ts";

export default function registerWebDocsFeature(pi: ExtensionAPI): void {
   registerWebDocsCommands(pi);
   const tools = returnRawWebTools();
   tools.forEach((t) => pi.registerTool(t));
}
