import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { DialogSelectOptions } from "@opencode/plugin/tui/context";
import { copyResponse } from "./copy-response";

type CopyContext = Parameters<typeof copyResponse>[0];
type Clipboard = Parameters<typeof copyResponse>[1];
type MessageRequest = Parameters<CopyContext["client"]["message"]["list"]>[0];
type MessagePage = Awaited<
  ReturnType<CopyContext["client"]["message"]["list"]>
>;
type AssistantMessage = Extract<
  MessagePage["data"][number],
  { type: "assistant" }
>;

function assistant(id: string, text: string): AssistantMessage {
  return {
    id,
    type: "assistant",
    agent: "plan",
    model: { providerID: "test", id: "test" },
    time: { created: 1_000, completed: 2_000 },
    content: [{ type: "text", text }],
  };
}

function harness(
  pages: MessagePage[] = [
    { data: [assistant("message", "Response")], cursor: {} },
  ],
  selection = 0,
) {
  const controller = new AbortController();
  const requests: MessageRequest[] = [];
  const writes: Parameters<Clipboard["writeText"]>[] = [];
  const dialogs: DialogSelectOptions<unknown>[] = [];
  const toasts: Parameters<CopyContext["ui"]["toast"]["show"]>[0][] = [];
  const context: CopyContext = {
    client: {
      message: {
        async list(input, options) {
          assert.equal(options?.signal, controller.signal);
          const page = pages[requests.length];
          requests.push(input);
          assert.ok(page, "Unexpected message page request");
          return page;
        },
      },
    },
    ui: {
      router: { current: () => ({ type: "session", sessionID: "current" }) },
      dialog: {
        async select<Value>(options: DialogSelectOptions<Value>) {
          dialogs.push(options);
          return options.options[selection]?.value;
        },
      },
      toast: {
        show(toast) {
          toasts.push(toast);
        },
      },
    },
  };
  const clipboard: Clipboard = {
    async writeText(...args) {
      writes.push(args);
      return {
        host: { status: "written" },
        terminal: { status: "not-attempted", capability: "unknown" },
      };
    },
  };

  return {
    context,
    clipboard,
    controller,
    requests,
    writes,
    dialogs,
    toasts,
    run: () => copyResponse(context, clipboard, controller.signal),
  };
}

describe("copy response", () => {
  it("paginates newest first and copies an older response without changing Markdown", async () => {
    const markdown = "  # Older response\n\n```ts\nconst x = 1;\n```\n";
    const test = harness(
      [
        {
          data: [assistant("new", "Newest response")],
          cursor: { next: "older" },
        },
        {
          data: [assistant("old", markdown)],
          cursor: { next: null, previous: "newer" },
        },
      ],
      1,
    );

    await test.run();

    assert.deepEqual(test.requests, [
      { sessionID: "current", type: "assistant", order: "desc", limit: 100 },
      { sessionID: "current", type: "assistant", cursor: "older", limit: 100 },
    ]);
    assert.deepEqual(test.dialogs[0]?.options, [
      {
        title: "Newest response",
        description: `plan · ${new Date(1_000).toLocaleString()}`,
        value: "Newest response",
      },
      {
        title: "# Older response ```ts const x = 1; ```",
        description: `plan · ${new Date(1_000).toLocaleString()}`,
        value: markdown,
      },
    ]);
    assert.deepEqual(test.writes, [
      [
        markdown,
        { destination: "best-available", signal: test.controller.signal },
      ],
    ]);
    assert.equal(test.toasts[0]?.variant, "success");
  });

  it("excludes reasoning, tools, blank messages, and non-assistant messages", async () => {
    const mixed = assistant("mixed", "First paragraph");
    mixed.content.push(
      { type: "reasoning", text: "Private reasoning" },
      {
        type: "tool",
        id: "tool",
        name: "read",
        state: { status: "streaming", input: "{}" },
        time: { created: 1_000 },
      },
      { type: "text", text: "Second paragraph\n" },
    );
    const reasoning = assistant("reasoning", "");
    reasoning.content = [{ type: "reasoning", text: "Private reasoning" }];
    const test = harness([
      {
        data: [
          {
            id: "idle",
            type: "idle",
            time: { created: 1_000 },
            outcome: "succeeded",
          },
          assistant("blank", " \n\t"),
          reasoning,
          mixed,
        ],
        cursor: {},
      },
    ]);

    await test.run();

    assert.equal(test.dialogs[0]?.options.length, 1);
    assert.equal(test.writes[0]?.[0], "First paragraph\n\nSecond paragraph\n");
  });

  it("shortens only the snippet, not the copied response", async () => {
    const text = "A long response. ".repeat(100);
    const test = harness([{ data: [assistant("long", text)], cursor: {} }]);

    await test.run();

    const option = test.dialogs[0]?.options[0];
    assert.equal(option?.title.length, 120);
    assert.equal(option?.title.endsWith("..."), true);
    assert.equal(test.writes[0]?.[0], text);
  });

  it("does not write to the clipboard when the picker is cancelled", async () => {
    const test = harness(undefined, -1);

    await test.run();

    assert.equal(test.dialogs.length, 1);
    assert.deepEqual(test.writes, []);
    assert.deepEqual(test.toasts, []);
  });

  it("reports empty history without opening a picker", async () => {
    const test = harness([{ data: [], cursor: {} }]);

    await test.run();

    assert.deepEqual(test.dialogs, []);
    assert.deepEqual(test.writes, []);
    assert.equal(test.toasts[0]?.message, "No assistant responses to copy.");
  });

  it("reports a failed history page instead of presenting a partial history", async () => {
    const test = harness([
      { data: [assistant("new", "Response")], cursor: { next: "older" } },
    ]);

    await test.run();

    assert.equal(test.requests.length, 2);
    assert.deepEqual(test.dialogs, []);
    assert.deepEqual(test.writes, []);
    assert.equal(test.toasts[0]?.variant, "error");
  });

  it("does nothing outside a session", async () => {
    const test = harness([]);
    test.context.ui.router.current = () => ({ type: "home" });

    await test.run();

    assert.deepEqual(test.requests, []);
    assert.deepEqual(test.dialogs, []);
    assert.deepEqual(test.toasts, []);
  });

  it("does not open a stale picker after the active session changes", async () => {
    const test = harness();
    const pending = test.run();
    test.context.ui.router.current = () => ({
      type: "session",
      sessionID: "other",
    });

    await pending;

    assert.deepEqual(test.dialogs, []);
    assert.deepEqual(test.writes, []);
  });

  it("stops loading silently when the plugin is unloaded", async () => {
    const test = harness([
      { data: [assistant("message", "Response")], cursor: { next: "older" } },
    ]);
    const pending = test.run();
    test.controller.abort();

    await pending;

    assert.equal(test.requests.length, 1);
    assert.deepEqual(test.dialogs, []);
    assert.deepEqual(test.writes, []);
    assert.deepEqual(test.toasts, []);
  });

  it("does not copy when unloaded while the picker is open", async () => {
    const test = harness();
    test.context.ui.dialog.select = async <Value>(
      options: DialogSelectOptions<Value>,
    ) => {
      test.controller.abort();
      return options.options[0]?.value;
    };

    await test.run();

    assert.deepEqual(test.writes, []);
    assert.deepEqual(test.toasts, []);
  });

  it("distinguishes an OSC52 attempt from a confirmed host write", async () => {
    const test = harness();
    test.clipboard.writeText = async () => ({
      host: { status: "not-attempted" },
      terminal: { status: "attempted", capability: "unknown" },
    });

    await test.run();

    assert.equal(test.toasts[0]?.variant, "info");
    assert.equal(
      test.toasts[0]?.message,
      "Response sent to terminal clipboard.",
    );
  });

  it("reports unavailable clipboard support instead of claiming success", async () => {
    const test = harness();
    test.clipboard.writeText = async () => ({
      host: { status: "unsupported" },
      terminal: { status: "not-attempted", capability: "unsupported" },
    });

    await test.run();

    assert.equal(test.toasts[0]?.variant, "error");
    assert.equal(
      test.toasts[0]?.message,
      "Clipboard write failed (unsupported).",
    );
  });

  it("reports clipboard exceptions", async () => {
    const test = harness();
    test.clipboard.writeText = async () => {
      throw new Error("Clipboard disconnected");
    };

    await test.run();

    assert.equal(test.toasts[0]?.variant, "error");
    assert.equal(test.toasts[0]?.message, "Clipboard disconnected");
  });
});
