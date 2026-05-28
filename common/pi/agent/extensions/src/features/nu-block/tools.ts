import { Text } from "@earendil-works/pi-tui";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { buildInvalidText, type NuValidationResult, validateNuBlock } from "./validator.ts";

export function registerNuBlockTools(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "emit-nu-block",
    label: "Emit Nu Block",
    description: "Validate, lint, format, and render user-facing Nushell output.",
    promptSnippet: "Validate and format user-facing Nushell blocks before replying.",
    promptGuidelines: [
      "Use emit-nu-block for every user-facing Nushell command or script block.",
      "Pass exact candidate Nushell to emit-nu-block before replying with shell.",
      "emit-nu-block enforces: multiline external commands wrapped in `( )`, no bare multiline externals, no bash continuation patterns, no backticks, no `&&`/`||`/`$()`/`export`/`[[ ]]`, no stray `^`, copy-paste-safe output.",
      "If emit-nu-block returns `status: invalid`, fix the Nushell and retry. Do not show rejected shell to the user.",
      "If emit-nu-block throws a tool/runtime error, retry once. If second retry also fails, answer exactly `tool didn't work after second retry`.",
      "When giving shell output, return only emit-nu-block output.",
    ],
    parameters: Type.Object({
      purpose: Type.String({ description: "One-line purpose shown above the Nushell block." }),
      script: Type.String({ description: "Raw candidate Nushell. No Markdown fences, no prose." }),
    }),
    execute: async (_toolCallId, params) => {
      const result = await validateNuBlock(params.purpose, params.script);
      const text = result.status === "ok" ? result.output : buildInvalidText(result);
      return { content: [{ type: "text", text }], details: result };
    },
    renderCall(args, theme) {
      return new Text(`${theme.fg("toolTitle", theme.bold("emit-nu-block"))} ${theme.fg("accent", args.purpose ?? "")}`, 0, 0);
    },
    renderResult(result, { expanded, isPartial }, theme) {
      if (isPartial) return new Text(theme.fg("warning", "Checking..."), 0, 0);
      const details = result.details as NuValidationResult | undefined;
      const textContent = result.content.find((content) => content.type === "text");
      if (!details || typeof details !== "object" || !("status" in details) || !textContent || textContent.type !== "text") return new Text("", 0, 0);
      if (details.status === "invalid") {
        if (!expanded) return new Text(theme.fg("error", `invalid · ${details.issues.length} issues`), 0, 0);
        return new Text(`\n${theme.fg("toolOutput", textContent.text)}`, 0, 0);
      }
      if (!expanded) {
        const lineCount = details.formattedScript.split("\n").length;
        return new Text(theme.fg("success", `ready · ${lineCount} lines`), 0, 0);
      }
      return new Text(`\n${theme.fg("toolOutput", textContent.text)}`, 0, 0);
    },
  });
}
