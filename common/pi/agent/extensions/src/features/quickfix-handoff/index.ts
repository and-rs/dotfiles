import { Text } from "@earendil-works/pi-tui";
import {
  copyToClipboard,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import {
  createQuickfixHandoff,
  type QuickfixHandoff,
  type QuickfixLocationInput,
} from "./quickfix.ts";

interface QuickfixHandoffParams {
  locations: QuickfixLocationInput[];
}

let lastQuickfixScript: string | null = null;

export default function registerQuickfixHandoffFeature(pi: ExtensionAPI): void {
  pi.on("session_start", () => {
    lastQuickfixScript = null;
  });

  pi.registerCommand("qf", {
    description: "Copy the latest quickfix handoff command.",
    handler: async (_args, ctx) => {
      if (!lastQuickfixScript)
        return ctx.ui.notify(
          "No quickfix handoff in this Pi session.",
          "warning",
        );
      try {
        await copyToClipboard(lastQuickfixScript);
        ctx.ui.notify("Quickfix command copied.", "info");
      } catch (error) {
        const message =
          error instanceof Error ? error.message : "unknown error";
        ctx.ui.notify(`Quickfix copy failed: ${message}`, "error");
      }
    },
  });

  pi.registerTool({
    name: "quickfix-handoff",
    label: "Quickfix Handoff",
    description:
      "Validate repository locations and render a user-run Nushell command that opens them in Neovim quickfix.",
    promptSnippet:
      "Whenever a repository reply points user to verified source, use quickfix-handoff to render the user-run command.",
    promptGuidelines: [
      "Use only locations verified through code-view or another read-only discovery tool.",
      "Call quickfix-handoff before replying when you name verified source locations, unless the user declines Neovim navigation.",
      "The command is user-facing output. After the tool, explain findings without repeating, reformatting, or wrapping the command.",
    ],
    parameters: Type.Object({
      locations: Type.Array(
        Type.Object({
          path: Type.String({ description: "File path inside cwd." }),
          line: Type.Integer({
            minimum: 1,
            description: "Verified 1-based line number.",
          }),
          column: Type.Optional(
            Type.Integer({
              minimum: 1,
              description: "1-based column. Default 1.",
            }),
          ),
          reason: Type.String({
            minLength: 1,
            description: "One-line reason for opening this location.",
          }),
        }),
        {
          minItems: 1,
          maxItems: 50,
          description: "Locations to include in quickfix order.",
        },
      ),
    }),
    execute: async (
      _toolCallId,
      params: QuickfixHandoffParams,
      _signal,
      _onUpdate,
      ctx,
    ) => {
      const handoff = await createQuickfixHandoff(ctx.cwd, params.locations);
      lastQuickfixScript = handoff.script;
      return {
        content: [
          {
            type: "text",
            text: "Quickfix handoff ready. Run /qf to copy it.",
          },
        ],
        details: handoff,
      };
    },
    renderCall(_args, theme) {
      return new Text(
        theme.fg("toolTitle", theme.bold("quickfix-handoff")),
        0,
        0,
      );
    },
    renderResult(result, _, theme) {
      const handoff = result.details as QuickfixHandoff | undefined;
      if (!handoff)
        return new Text(theme.fg("warning", "No quickfix handoff"), 0, 0);

      return new Text(
        `${theme.bg("userMessageBg", theme.bold(theme.fg("mdCode", " handoff ready ··· run /qf to copy it ")))}`,
        0,
        0,
      );
    },
  });
}
