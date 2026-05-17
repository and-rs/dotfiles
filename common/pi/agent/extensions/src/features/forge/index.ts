import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerForgeCommands } from "./commands.ts";
import { createForgeRuntime, registerForgeEvents } from "./events.ts";

export default function registerForgeFeature(pi: ExtensionAPI): void {
  const runtime = createForgeRuntime(pi);
  registerForgeCommands(pi, runtime);
  registerForgeEvents(pi, runtime);
}
