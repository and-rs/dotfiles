import { Plugin } from "@opencode/plugin/tui";
import type { ColorInput } from "@opentui/core";
import {
  createEffect,
  createMemo,
  createSignal,
  onCleanup,
  Show,
} from "solid-js";
import stringWidth from "string-width";
import { branchMarqueeCycleLength, branchMarqueeFrame } from "./branch-marquee";
import { compactPath } from "./text-width";

const spinnerWidth = 2;
const titleWidthReserve = 24;
const pathWidthLimit = 24;
const branchWidthLimit = 12;
const branchScrollInterval = 200;
const locationMinWidth = 70;

function randomSpinnerFrame() {
  // Sample the Unicode box-drawing block (U+2500–U+257F).
  return Array.from({ length: spinnerWidth }, () =>
    String.fromCharCode(0x2500 + Math.floor(Math.random() * 128)),
  ).join("");
}

function TurnSpinner() {
  const [frame, setFrame] = createSignal(randomSpinnerFrame());
  const timer = setInterval(() => {
    setFrame(randomSpinnerFrame());
  }, 50);
  onCleanup(() => clearInterval(timer));

  return <>{frame()}</>;
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
  return <>{` Ρ · ${compactPath(props.path, pathWidth())} (no branch) `}</>;
}

function FooterLocation(props: {
  path: string;
  branch: string | undefined;
  statsWidth: number;
  statusWidth: number;
  titleWidth: number;
  width: number;
  bg: ColorInput;
  fg: ColorInput;
}) {
  const locationWidth = () =>
    Math.max(
      0,
      props.width - props.statsWidth - props.statusWidth - props.titleWidth - 3,
    );

  return (
    <Show
      when={
        props.width >= locationMinWidth &&
        locationWidth() >= stringWidth(" Ρ ·  (no branch) ") + 1
      }
    >
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
      render: (props) => {
        const textColor = context.theme.background.raised.high;
        const backgroundColor = context.theme.text.feedback.info.base;
        const [width, setWidth] = createSignal(0);
        const session = createMemo(() => {
          if (props.sessionID) return context.data.session.get(props.sessionID);
        });
        const title = () => session()?.title || "New session";
        const titleWidth = () =>
          Math.min(titleWidthReserve, stringWidth(title()));

        const stats = createMemo(() => {
          let currentTokens: number | undefined;
          let assistantModel: { providerID: string; id: string } | undefined;
          let contextWindow: number | undefined;

          if (props.sessionID) {
            const messages = context.data.session.message.list(props.sessionID);
            let end = messages.length;
            const revert = session()?.revert;
            if (revert) {
              const messageID = revert.messageID;
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

          if (
            currentTokens !== undefined &&
            contextWindow &&
            contextWindow > 0
          ) {
            const current = formatTokens(currentTokens);
            const window = formatTokens(contextWindow);
            const percentage = `${Math.round((currentTokens / contextWindow) * 100)}%`;
            return ` Σ · ${current} / ${window} (${percentage}) `;
          }
        });

        const branch = () =>
          context.data.location.vcs.info(location)?.branch.current;
        const path = () =>
          context.ui.format.path(
            session()?.location.directory ?? location.directory,
          );
        const isRunning = () => {
          if (!props.sessionID) return false;
          return context.data.session.status(props.sessionID) === "running";
        };
        const statusWidth = () => {
          if (isRunning()) return spinnerWidth + 2;
          return stringWidth(" β ");
        };
        const visibleStats = () => {
          const value = stats();
          if (
            value &&
            width() >= statusWidth() + titleWidth() + stringWidth(value) + 2
          ) {
            return value;
          }
        };
        const statsWidth = () => stringWidth(visibleStats() ?? "");

        return (
          <box
            flexDirection="row"
            justifyContent="space-between"
            width="100%"
            gap={1}
            onSizeChange={function () {
              setWidth(this.width);
            }}
          >
            <box
              flexDirection="row"
              flexGrow={1}
              flexShrink={1}
              minWidth={0}
              gap={1}
            >
              <text
                bg={textColor}
                fg={backgroundColor}
                wrapMode="none"
                flexShrink={0}
              >
                {" "}
                <Show when={isRunning()} fallback="β">
                  <TurnSpinner />
                </Show>{" "}
              </text>

              <text
                fg={backgroundColor}
                wrapMode="none"
                truncate
                flexGrow={1}
                flexShrink={1}
                minWidth={0}
              >
                {title()}
              </text>
            </box>

            <box
              flexDirection="row"
              justifyContent="flex-end"
              flexShrink={0}
              gap={1}
            >
              <Show when={visibleStats()}>
                {(value: () => string) => (
                  <text bg={textColor} fg={backgroundColor} wrapMode="none">
                    {value()}
                  </text>
                )}
              </Show>
              <FooterLocation
                path={path()}
                branch={branch()}
                statsWidth={statsWidth()}
                statusWidth={statusWidth()}
                titleWidth={titleWidth()}
                width={width()}
                bg={textColor}
                fg={backgroundColor}
              />
            </box>
          </box>
        );
      },
    });
  },
});
