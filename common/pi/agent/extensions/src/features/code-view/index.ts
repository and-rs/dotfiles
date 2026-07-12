import { Text } from "@earendil-works/pi-tui";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { formatCodeView, readCodeView, type CodeViewResult } from "./read.ts";

interface CodeViewParams {
  path: string;
  start?: number;
  end?: number;
}

export default function registerCodeViewFeature(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "code-view",
    label: "Code View",
    description: "Read a bounded source range with plain line numbers. Does not edit files.",
    promptSnippet: "Use code-view to inspect exact source after discovery. Cite its path and line numbers when explaining behavior.",
    promptGuidelines: [
      "Use code-view after search identifies a relevant file or symbol.",
      "Read the smallest useful line range; use another range for more context.",
      "Treat code-view output as evidence and cite its path and line numbers in plans.",
    ],
    parameters: Type.Object({
      path: Type.String({ description: "File path inside cwd." }),
      start: Type.Optional(Type.Integer({ minimum: 1, description: "First line to read. Default 1." })),
      end: Type.Optional(Type.Integer({ minimum: 1, description: "Last line to read. Defaults to 400 lines after start." })),
    }),
    execute: async (_toolCallId, params: CodeViewParams, _signal, _onUpdate, ctx) => {
      const result = await readCodeView(ctx.cwd, params.path, params.start, params.end);
      return { content: [{ type: "text", text: formatCodeView(result) }], details: result };
    },
    renderCall(args, theme) {
      const range = args.start === undefined ? "" : `:${args.start}${args.end === undefined ? "" : `-${args.end}`}`;
      return new Text(`${theme.fg("toolTitle", theme.bold("code-view"))} ${theme.fg("accent", `${args.path ?? ""}${range}`)}`, 0, 0);
    },
    renderResult(result, { expanded }, theme) {
      const details = result.details as CodeViewResult | undefined;
      if (!details) return new Text(theme.fg("warning", "No source details"), 0, 0);
      const summary = `${details.path}:${details.startLine}-${details.endLine} of ${details.totalLines}`;
      if (!expanded) return new Text(theme.fg("success", summary), 0, 0);
      const text = result.content.find((item) => item.type === "text")?.text ?? "";
      return new Text(`\n${theme.fg("toolOutput", text)}`, 0, 0);
    },
  });
}
