import type { Plugin } from "@opencode/plugin/tui";
import type { DialogSelectOption } from "@opencode/plugin/tui/context";
import type { ClipboardService } from "@opentui/core";

type CopyContext = {
  client: Pick<Plugin.Context["client"], "message">;
  ui: {
    router: Pick<Plugin.Context["ui"]["router"], "current">;
    dialog: Pick<Plugin.Context["ui"]["dialog"], "select">;
    toast: Plugin.Context["ui"]["toast"];
  };
};

export async function copyResponse(
  context: CopyContext,
  clipboard: Pick<ClipboardService, "writeText">,
  signal: AbortSignal,
): Promise<void> {
  const route = context.ui.router.current();
  if (route.type !== "session" || signal.aborted) return;

  try {
    const options: DialogSelectOption<string>[] = [];
    let pagination: { order: "desc" } | { cursor: string } = { order: "desc" };

    while (!signal.aborted) {
      const page = await context.client.message.list(
        {
          sessionID: route.sessionID,
          type: "assistant",
          limit: 100,
          ...pagination,
        },
        { signal },
      );
      if (signal.aborted) return;

      for (const message of page.data) {
        if (message.type !== "assistant") continue;
        const text = message.content
          .filter((part) => part.type === "text")
          .map((part) => part.text)
          .join("\n\n");
        if (!text.trim()) continue;

        let title = text.replace(/\s+/gu, " ").trim();
        if (title.length > 120) title = `${title.slice(0, 117)}...`;
        options.push({
          title,
          description: `${message.agent} · ${new Date(message.time.created).toLocaleString()}`,
          value: text,
        });
      }

      if (!page.cursor.next) break;
      pagination = { cursor: page.cursor.next };
    }

    const current = context.ui.router.current();
    if (
      signal.aborted ||
      current.type !== "session" ||
      current.sessionID !== route.sessionID
    ) {
      return;
    }
    if (options.length === 0) {
      context.ui.toast.show({
        message: "No assistant responses to copy.",
        variant: "info",
      });
      return;
    }

    const text = await context.ui.dialog.select({
      title: "Copy an agent response",
      placeholder: "Search response snippets…",
      options,
    });
    if (text === undefined || signal.aborted) return;

    const result = await clipboard.writeText(text, {
      destination: "best-available",
      signal,
    });
    if (signal.aborted) return;
    if (result.host.status === "written") {
      context.ui.toast.show({
        message: "Response copied to clipboard.",
        variant: "success",
      });
      return;
    }
    if (result.terminal.status === "attempted") {
      context.ui.toast.show({
        message: "Response sent to terminal clipboard.",
        variant: "info",
      });
      return;
    }
    throw new Error(`Clipboard write failed (${result.host.status}).`);
  } catch (error) {
    if (signal.aborted) return;
    let message = "Could not copy response.";
    if (error instanceof Error) message = error.message;
    context.ui.toast.show({
      title: "Copy response",
      message,
      variant: "error",
    });
  }
}
