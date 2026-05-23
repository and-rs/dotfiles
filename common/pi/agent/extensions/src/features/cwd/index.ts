import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerCwdCommands } from "./commands.ts";

export default function registerCwdFeature(pi: ExtensionAPI): void {
  registerCwdCommands(pi);
}
