import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerSessionNameEvents } from "./events.ts";

export default function registerSessionNameFeature(pi: ExtensionAPI): void {
  registerSessionNameEvents(pi);
}
