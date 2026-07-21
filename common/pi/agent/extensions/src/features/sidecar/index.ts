import {
  createAgentSession,
  getMarkdownTheme,
  ModelRuntime,
  SessionManager,
  type ExtensionAPI,
  type CreateAgentSessionResult,
} from "@earendil-works/pi-coding-agent";
import { Box, Markdown, Component } from "@earendil-works/pi-tui";
import { returnRawWebTools } from "../web-docs/tools";

export default function registerSidecarCommand(pi: ExtensionAPI): void {
  pi.registerEntryRenderer("sidecar", (entry, _, theme) => {
    const data = entry.data as string;
    const mdTheme = getMarkdownTheme();
    mdTheme.hr = (lines) => {
      return theme.fg("dim", lines);
    };
    mdTheme.codeBlockIndent = "";
    const container = new Box(0, 0, (text) => {
      return theme.bg("userMessageBg", text);
    });
    const border: Component = {
      render: (w) => {
        let i = 0;
        let store = "";
        while (i < w) {
          store += "─";
          i++;
        }
        return [theme.fg("success", store)];
      },
      invalidate: () => {},
    };
    const mdContent = new Markdown(
      `${theme.fg("success", "Sidecar:")} ${data}`,
      1,
      0,
      mdTheme,
    );
    container.addChild(border);
    container.addChild(mdContent);
    container.addChild(border);
    return container;
  });

  pi.registerCommand("side", {
    description:
      "Make a question to the sidecar without getting into the context.",

    handler: async (args, ctx) => {
      let result: CreateAgentSessionResult;
      try {
        const question = args.trim();
        if (question.length < 1) {
          throw Error("Type your message");
        }
        ctx.ui.setWidget("sidecar-loader", ["Sidecar thinking..."]);
        const modelRuntime = await ModelRuntime.create();
        const customTools = returnRawWebTools();
        result = await createAgentSession({
          cwd: ctx.cwd,
          modelRuntime,
          model: ctx.model,
          agentDir: ctx.cwd,
          thinkingLevel: "medium",
          sessionManager: SessionManager.inMemory(ctx.cwd),
          tools: ["web-fetch", "exa-search"],
          customTools,
        });
        if (!result.session) {
          throw Error("Could not create session");
        }
        await result.session.prompt(question);
        const answer = result.session.getLastAssistantText();
        if (!answer) {
          throw Error("No answer received");
        }
        pi.appendEntry("sidecar", answer);
      } catch (error) {
        const message =
          error instanceof Error ? error.message : "unknown error";
        ctx.ui.notify(`Sidecar question failed: ${message}`, "error");
      } finally {
        ctx.ui.setWidget("sidecar-loader", undefined);
        result?.session.dispose();
      }
    },
  });
}
