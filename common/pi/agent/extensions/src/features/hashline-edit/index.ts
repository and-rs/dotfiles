import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerHashlineEditTools } from "./tools.ts";

type ActiveToolAPI = ExtensionAPI & {
  getActiveTools?: () => string[];
  setActiveTools?: (toolNames: string[]) => void;
};

function activateDefaultTools(pi: ExtensionAPI): void {
  const api = pi as ActiveToolAPI;
  const active = typeof api.getActiveTools === "function" ? api.getActiveTools() : [];
  const filtered = active.filter((name) => name !== "edit" && name !== "write" && name !== "read");
  const next = Array.from(new Set([...filtered, "hashline-read", "hashline-edit", "file-create", "read-image"]));
  if (typeof api.setActiveTools === "function") api.setActiveTools(next);
}

export default function registerHashlineEditFeature(pi: ExtensionAPI): void {
  pi.on("session_start", () => activateDefaultTools(pi));

  registerHashlineEditTools(pi);
}
