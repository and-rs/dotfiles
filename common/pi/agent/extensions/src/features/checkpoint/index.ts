import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerCheckpointEvents } from "./events.ts";
import { registerCheckpointRenderers } from "./renderers.ts";

export default function registerCheckpointFeature(pi: ExtensionAPI): void {
  const sendCheckpointMessage = registerCheckpointRenderers(pi);
  registerCheckpointEvents(pi, sendCheckpointMessage);
}
