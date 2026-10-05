import { Plugin } from "@opencode/plugin/tui";
import { createSignal, onCleanup, Show } from "solid-js";

const spinnerFrames = ["⣾", "⣷", "⣯", "⣟", "⡿", "⢿", "⣻", "⣽"];

function TurnSpinner() {
  const [frame, setFrame] = createSignal(0);
  const timer = setInterval(() => {
    setFrame((current) => (current + 1) % spinnerFrames.length);
  }, 80);
  onCleanup(() => clearInterval(timer));

  return <>{spinnerFrames[frame()]}</>;
}

function formatTokens(tokens: number): string {
  if (tokens >= 1_000_000) {
    return `${(tokens / 1_000_000).toFixed(1)}M`;
  }
  if (tokens >= 1_000) {
    return `${(tokens / 1_000).toFixed(1)}K`;
  }
  return tokens.toString();
}

export default Plugin.define({
  id: "context-footer",
  async setup(context) {
    const location = context.location ?? context.data.location.default();
    await context.data.location.vcs.sync(location);

    context.ui.slot({
      replace: "prompt.footer",
      render: ({ sessionID }) => {
        let currentTokens: number | undefined;
        let assistantModel: { providerID: string; id: string } | undefined;
        let contextWindow: number | undefined;

        let session: ReturnType<typeof context.data.session.get>;
        if (sessionID) {
          session = context.data.session.get(sessionID);
          const messages = context.data.session.message.list(sessionID);
          let end = messages.length;
          if (session?.revert) {
            const messageID = session.revert.messageID;
            const revertedMessage = messages.findIndex(
              (message) => message.id === messageID,
            );
            if (revertedMessage !== -1) end = revertedMessage;
          }

          let lastCompaction = -1;
          for (let index = 0; index < end; index++) {
            const message = messages[index];
            if (
              message?.type === "compaction" &&
              message.status === "completed"
            ) {
              lastCompaction = index;
            }
          }

          for (let index = end - 1; index > lastCompaction; index--) {
            const message = messages[index];
            if (message?.type !== "assistant" || !message.tokens) continue;

            const tokens =
              message.tokens.input +
              message.tokens.output +
              message.tokens.reasoning +
              message.tokens.cache.read +
              message.tokens.cache.write;
            if (tokens <= 0) continue;

            currentTokens = tokens;
            assistantModel = message.model;
            break;
          }
        }

        if (assistantModel) {
          const model = context.data.location.model
            .list(location)
            ?.find(
              (entry) =>
                entry.providerID === assistantModel.providerID &&
                entry.id === assistantModel.id,
            );
          contextWindow = model?.limit.context;
        }

        let window = "No max. tokens found";
        if (contextWindow) window = formatTokens(contextWindow);

        let current = "—";
        let percentage = "—";
        if (currentTokens !== undefined) {
          current = formatTokens(currentTokens);
          if (contextWindow) {
            percentage = `${Math.round((currentTokens / contextWindow) * 100)}%`;
          }
        }

        let directory = location.directory;
        if (session?.location.directory) directory = session.location.directory;
        const branch = context.data.location.vcs.info(location)?.branch.current;
        let pathBranch = context.ui.format.path(directory);
        if (branch) {
          pathBranch += ` (${branch})`;
        } else {
          pathBranch += " (no branch)";
        }
        const isRunning = () => {
          if (!sessionID) return false;
          return context.data.session.status(sessionID) === "running";
        };

        return (
          <box flexDirection="row" justifyContent="space-between" width="100%">
            <box flexGrow={1} flexShrink={1} minWidth={0}>
              <box flexDirection="row" gap={1}>
                <text
                  bg={context.theme.text.muted}
                  fg={context.theme.background.base}
                >
                  {" "}
                  <Show when={isRunning()} fallback="β">
                    <TurnSpinner />
                  </Show>{" "}
                </text>

                <Show when={isRunning()}>
                  <text fg={context.theme.text.muted}>Working</text>
                </Show>
              </box>
            </box>

            <box flexDirection="row" justifyContent="flex-end" gap={1}>
              <text
                bg={context.theme.text.muted}
                fg={context.theme.background.base}
              >{` Σ · ${current} / ${window} (${percentage}) `}</text>
              <text
                bg={context.theme.text.muted}
                fg={context.theme.background.base}
              >{` Ρ · ${pathBranch} `}</text>
            </box>
          </box>
        );
      },
    });
  },
});
