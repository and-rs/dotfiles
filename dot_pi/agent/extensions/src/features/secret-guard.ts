import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PATH_TOOLS = new Set([
  "read",
  "grep",
  "find",
  "write",
  "edit",
  "ls",
  "read-image",
]);
const SECRET_PATH = /(^|[\\/\s'"`=])\.env(?:$|[.\\/\s'"`])/i;

export default function registerSecretGuard(pi: ExtensionAPI): void {
  pi.on("tool_call", (event) => {
    const input = event.input as Record<string, unknown>;
    let value: unknown;
    if (event.toolName === "bash") {
      value = input.command;
    } else {
      value = input.path;
    }
    if (
      typeof value === "string" &&
      SECRET_PATH.test(value) &&
      (event.toolName === "bash" || PATH_TOOLS.has(event.toolName))
    ) {
      return { block: true, reason: "Access to .env files is denied." };
    }
    return undefined;
  });
}
