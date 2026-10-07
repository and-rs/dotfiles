import { Plugin } from "@opencode/plugin/tui";
import { useTerminalDimensions } from "@opentui/solid";
import { createEffect, createSignal, onCleanup, Show } from "solid-js";
import stringWidth from "string-width";
import { branchMarqueeCycleLength, branchMarqueeFrame } from "./branch-marquee";
import { compactPath } from "./text-width";

const spinnerFrames = ["⣾", "⣷", "⣯", "⣟", "⡿", "⢿", "⣻", "⣽"];
const pathWidthLimit = 24;
const branchWidthLimit = 12;
const branchScrollInterval = 200;
const locationMinTerminalWidth = 70;

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

function BranchTicker(props: { branch: string; maxWidth: number }) {
  const [offset, setOffset] = createSignal(0);
  const frame = () =>
    branchMarqueeFrame(props.branch, props.maxWidth, offset());

  createEffect(() => {
    const branch = props.branch;
    const width = props.maxWidth;
    setOffset(0);
    if (stringWidth(branch) <= width) return;

    const cycleLength = branchMarqueeCycleLength(branch);
    const timer = setInterval(() => {
      setOffset((current) => (current + 1) % cycleLength);
    }, branchScrollInterval);
    onCleanup(() => clearInterval(timer));
  });

  return <>{frame()}</>;
}

function NoBranchLocation(props: {
  path: string;
  locationWidth: () => number;
}) {
  const fixedWidth = stringWidth(" Ρ ·  (no branch) ");
  const pathWidth = () =>
    Math.min(pathWidthLimit, Math.max(1, props.locationWidth() - fixedWidth));
  return ` Ρ · ${compactPath(props.path, pathWidth())} (no branch) `;
}

function FooterLocation(props: {
  path: string;
  branch: string | undefined;
  statsWidth: number;
  statusWidth: number;
  bg: string;
  fg: string;
}) {
  const dimensions = useTerminalDimensions();
  const locationWidth = () =>
    Math.max(1, dimensions().width - props.statsWidth - props.statusWidth - 3);

  return (
    <Show when={dimensions().width >= locationMinTerminalWidth}>
      <text bg={props.bg} fg={props.fg} wrapMode="none">
        <Show
          when={props.branch}
          fallback={
            <NoBranchLocation path={props.path} locationWidth={locationWidth} />
          }
        >
          {(branch: () => string) => {
            const fixedWidth = stringWidth(" Ρ ·  () ");
            const maxPathWidth = () =>
              Math.min(
                pathWidthLimit,
                Math.max(1, Math.floor((locationWidth() - fixedWidth) * 0.6)),
              );
            const path = () => compactPath(props.path, maxPathWidth());
            const branchWidth = () =>
              Math.max(
                1,
                Math.min(
                  branchWidthLimit,
                  locationWidth() - fixedWidth - stringWidth(path()),
                ),
              );

            return (
              <>
                {` Ρ · ${path()} (`}
                <BranchTicker branch={branch()} maxWidth={branchWidth()} />
                {`) `}
              </>
            );
          }}
        </Show>
      </text>
    </Show>
  );
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

          for (let index = end - 1; index >= 0; index--) {
            const message = messages[index];
            if (
              message?.type === "compaction" &&
              message.status === "completed"
            ) {
              break;
            }
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

        let stats: string | undefined;
        if (currentTokens !== undefined && contextWindow && contextWindow > 0) {
          const current = formatTokens(currentTokens);
          const window = formatTokens(contextWindow);
          const percentage = `${Math.round((currentTokens / contextWindow) * 100)}%`;
          stats = ` Σ · ${current} / ${window} (${percentage}) `;
        }

        let directory = location.directory;
        if (session?.location.directory) directory = session.location.directory;
        const branch = context.data.location.vcs.info(location)?.branch.current;
        const path = context.ui.format.path(directory);
        let isRunning = false;
        if (sessionID) {
          isRunning = context.data.session.status(sessionID) === "running";
        }
        let statsWidth = 0;
        if (stats) statsWidth = stringWidth(stats);
        let statusWidth = stringWidth(" β ");
        if (isRunning) {
          statusWidth += 1 + stringWidth("Working");
        }

        return (
          <box flexDirection="row" justifyContent="space-between" width="100%">
            <box flexGrow={1} flexShrink={0} minWidth={0}>
              <box flexDirection="row" gap={1}>
                <text
                  bg={context.theme.text.muted}
                  fg={context.theme.background.base}
                  wrapMode="none"
                >
                  {" "}
                  <Show when={isRunning} fallback="β">
                    <TurnSpinner />
                  </Show>{" "}
                </text>

                <Show when={isRunning}>
                  <text fg={context.theme.text.muted} wrapMode="none">
                    Working
                  </text>
                </Show>
              </box>
            </box>

            <box flexDirection="row" justifyContent="flex-end" gap={1}>
              <Show when={stats}>
                {(value: () => string) => (
                  <text
                    bg={context.theme.text.muted}
                    fg={context.theme.background.base}
                    wrapMode="none"
                  >
                    {value()}
                  </text>
                )}
              </Show>
              <FooterLocation
                path={path}
                branch={branch}
                statsWidth={statsWidth}
                statusWidth={statusWidth}
                bg={context.theme.text.muted}
                fg={context.theme.background.base}
              />
            </box>
          </box>
        );
      },
    });
  },
});
