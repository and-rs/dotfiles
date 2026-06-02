import { Text } from "@earendil-works/pi-tui";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { buildInvalidText, type NuValidationResult, validateNuBlock } from "./validator.ts";

export function registerNuBlockTools(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "emit-nu-block",
    label: "Emit Nu Block",
    description: "Validate, lint, format, and render user-facing Nushell output.",
    promptSnippet: "Render user-facing Nushell through emit-nu-block.",
    promptGuidelines: [
      "Any Nushell shown to user must come from emit-nu-block.",
      "Pass exact candidate Nushell to emit-nu-block before replying.",
      "If emit-nu-block rejects shell, fix Nushell and retry; never show rejected shell.",
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
        if (!expanded) return new Text(theme.fg("error", `invalid · ${details.issues.length} ${details.issues.length === 1 ? "issue" : "issues"}`), 0, 0);
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
