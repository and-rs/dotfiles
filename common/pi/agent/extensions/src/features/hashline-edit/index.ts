import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerHashlineEditTools } from "./tools.ts";

export default function registerHashlineEditFeature(pi: ExtensionAPI): void {
  pi.on("session_start", () => {
    const api = pi as unknown as {
      getActiveTools?: () => string[];
      setActiveTools?: (toolNames: string[]) => void;
    };
    const active = typeof api.getActiveTools === "function" ? api.getActiveTools() : [];
    const filtered = active.filter((name) => name !== "edit" && name !== "write" && name !== "read");
    const next = Array.from(new Set([...filtered, "hashline-read", "hashline-edit", "file-create"]));
    if (typeof api.setActiveTools === "function") api.setActiveTools(next);
  });

  registerHashlineEditTools(pi);
}
