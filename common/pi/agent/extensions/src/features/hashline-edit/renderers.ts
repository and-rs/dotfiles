import { Text } from "@earendil-works/pi-tui";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export function blockedToolMessage(toolName: string): string {
  return `Tool "${toolName}" is disabled. Use hashline-edit with {path, goal} for existing-file edits, and file-create for new files.`;
}

export function registerBlockedFileTool(pi: ExtensionAPI, name: "read" | "edit" | "write"): void {
  pi.registerTool({
    name,
    label: `${name} disabled`,
    description: blockedToolMessage(name),
    promptSnippet: blockedToolMessage(name),
    parameters: Type.Object({}),
    execute: async () => {
      throw new Error(blockedToolMessage(name));
    },
    renderResult(_result, _options, theme) {
      return new Text(theme.fg("error", blockedToolMessage(name)), 0, 0);
    },
  });
}
