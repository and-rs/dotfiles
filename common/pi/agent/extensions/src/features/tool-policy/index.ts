import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerToolPolicyEvents } from "./events.ts";

export default function registerToolPolicyFeature(pi: ExtensionAPI): void {
  registerToolPolicyEvents(pi);
}
