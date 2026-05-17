import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerFocusBorderEvents } from "./events.ts";

export default function registerFocusBorderFeature(pi: ExtensionAPI): void {
  registerFocusBorderEvents(pi);
}
