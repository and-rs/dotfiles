import {
  createAgentSession,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { complete, Context, UserMessage } from "@earendil-works/pi-ai/compat";

export default function registerSidecarCommand(pi: ExtensionAPI): void {
  pi.registerCommand("side", {
    description:
      "Make a question to the sidecar without getting into the context.",
    handler: async (args, ctx) => {
      try {
        const question = args.trim();
        if (question.length < 1) {
          ctx.ui.notify("Sidecar question empty, type your message", "error");
          return;
        }

        const model = ctx.model;
        if (!model) {
          ctx.ui.notify("No model available for Sidecar question.", "error");
          return;
        }

        const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
        if (!auth || !auth.ok) {
          ctx.ui.notify(
            "No auth headers available for Sidecar question.",
            "error",
          );
          return;
        }
        const options = { apiKey: auth.apiKey, headers: auth.headers };

        const systemPrompt =
          "Answer side question briefly. Search online if required to answer. Be brief:\n";

        const userMessage: UserMessage = {
          role: "user",
          content: question,
          timestamp: Date.now(),
        };

        const context: Context = { systemPrompt, messages: [userMessage] };

        const { session } = await createAgentSession({
          cwd: ctx.cwd,
          agentDir: ctx.cwd,
          model,
          thinkingLevel: "medium",
          tools: ["exa-search", "web-fetch"],
        });

        const response = await session.prompt(question);

        if (!response.content) {
          ctx.ui.notify("No answer received from Sidecar model.", "error");
          return;
        }

        const answer = response.content.join("\n");
        ctx.ui.notify(answer, "info");
      } catch (error) {
        const message =
          error instanceof Error ? error.message : "unknown error";
        ctx.ui.notify(`Sidecar question failed: ${message}`, "error");
      }
    },
  });
}
