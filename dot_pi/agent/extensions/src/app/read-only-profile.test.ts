import assert from "node:assert/strict";
import test from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import registerApp from "./index.ts";
import { DISCOVERY_TOOLS, getMode, resetModes } from "./modes.ts";

type EventHandler = (...args: unknown[]) => unknown;

const BUILD_TOOLS = [...DISCOVERY_TOOLS, "bash", "edit", "write"];

const emptyCtx = {
  hasUI: false,
  sessionManager: { getEntries: () => [] },
};

function createPi(opts?: { sendUserMessage?: (text: string) => unknown }) {
  resetModes();
  const registeredTools: string[] = [];
  const activeToolSets: string[][] = [];
  const sent: string[] = [];
  const entries: Array<{ name?: string }> = [];
  const commands = new Map<string, { handler: EventHandler }>();
  const eventHandlers = new Map<string, EventHandler[]>();
  const shortcuts = new Map<string, { handler: () => void }>();
  const pi = {
    registerTool(tool: { name: string }) {
      registeredTools.push(tool.name);
    },
    registerCommand(name: string, spec: { handler: EventHandler }) {
      commands.set(name, spec);
    },
    registerEntryRenderer() {},
    registerShortcut(name: string, spec: { handler: () => void }) {
      shortcuts.set(name, spec);
    },
    appendEntry(_type: string, data: { name?: string }) {
      entries.push(data);
    },
    sendUserMessage(text: string) {
      if (opts?.sendUserMessage) return opts.sendUserMessage(text);
      sent.push(text);
    },
    setActiveTools(toolNames: string[]) {
      activeToolSets.push(toolNames);
    },
    on(event: string, handler: EventHandler) {
      const handlers = eventHandlers.get(event) ?? [];
      handlers.push(handler);
      eventHandlers.set(event, handlers);
    },
  } as unknown as ExtensionAPI;

  registerApp(pi);

  return {
    registeredTools,
    activeToolSets,
    sent,
    entries,
    commands,
    eventHandlers,
    shortcuts,
  };
}

test("new session defaults to plan discovery tools", async () => {
  const { registeredTools, activeToolSets, eventHandlers } = createPi();

  assert.deepEqual(registeredTools, ["read-image", "exa-search", "web-fetch"]);

  const sessionStart = eventHandlers.get("session_start")?.at(-1);
  assert.ok(sessionStart);
  await sessionStart?.({}, emptyCtx);

  assert.equal(getMode(), "plan");
  assert.deepEqual(activeToolSets.at(-1), [...DISCOVERY_TOOLS]);
});

test("tab cycles plan and build only", async () => {
  const { activeToolSets, entries, eventHandlers, shortcuts } = createPi();
  const sessionStart = eventHandlers.get("session_start")?.at(-1);
  await sessionStart?.({}, emptyCtx);

  const tab = shortcuts.get("tab");
  assert.ok(tab);
  tab.handler();
  assert.equal(getMode(), "build");
  assert.deepEqual(activeToolSets.at(-1), BUILD_TOOLS);
  assert.deepEqual(entries.at(-1), { name: "build" });

  tab.handler();
  assert.equal(getMode(), "plan");
  assert.deepEqual(
    entries.map((entry) => entry.name),
    ["build", "plan"],
  );
});

test("restore ignores persisted teach and keeps plan", async () => {
  const { eventHandlers } = createPi();
  const sessionStart = eventHandlers.get("session_start")?.at(-1);
  await sessionStart?.(
    {},
    {
      hasUI: false,
      sessionManager: {
        getEntries: () => [
          { type: "custom", customType: "agent-mode", data: { name: "teach" } },
        ],
      },
    },
  );
  assert.equal(getMode(), "plan");
});

test("before_agent_start uses plan layer without replacing the prompt", async () => {
  const { activeToolSets, eventHandlers } = createPi();
  await eventHandlers.get("session_start")?.at(-1)?.({}, emptyCtx);
  const beforeAgentStart = eventHandlers.get("before_agent_start")?.at(-1);
  assert.ok(beforeAgentStart);

  const event = {
    systemPrompt: "base",
    systemPromptOptions: {
      selectedTools: ["read", "bash", "edit", "write"],
    },
  };
  const result = (await beforeAgentStart?.(event, {})) as
    | { systemPrompt?: string }
    | undefined;

  assert.match(result?.systemPrompt ?? "", /^base\n\n/);
  assert.match(result?.systemPrompt ?? "", /<plan>/);
  assert.match(
    result?.systemPrompt ?? "",
    /Stay in the current working directory/,
  );
  assert.deepEqual(event.systemPromptOptions.selectedTools, [
    ...DISCOVERY_TOOLS,
  ]);
  assert.deepEqual(activeToolSets.at(-1), [...DISCOVERY_TOOLS]);
  assert.equal(event.systemPrompt, "base");
});

test("before_agent_start appends layers when options are missing", async () => {
  const { eventHandlers } = createPi();
  await eventHandlers.get("session_start")?.at(-1)?.({}, emptyCtx);
  const result = (await eventHandlers.get("before_agent_start")?.at(-1)?.(
    { systemPrompt: "base" },
    {},
  )) as { systemPrompt?: string } | undefined;

  assert.match(result?.systemPrompt ?? "", /^base\n\n/);
  assert.match(result?.systemPrompt ?? "", /<plan>/);
  assert.match(
    result?.systemPrompt ?? "",
    /Stay in the current working directory/,
  );
});

test("/teach sends one coaching turn then restores cycle mode", async () => {
  const { activeToolSets, commands, eventHandlers, sent } = createPi();
  await eventHandlers.get("session_start")?.at(-1)?.({}, emptyCtx);

  const teach = commands.get("teach");
  assert.ok(teach);
  const notifies: string[] = [];
  await teach.handler("why is this layered", {
    isIdle: () => true,
    ui: { notify: (msg: string) => notifies.push(msg) },
  });

  assert.equal(getMode(), "teach");
  assert.deepEqual(sent, ["why is this layered"]);
  assert.deepEqual(activeToolSets.at(-1), [...DISCOVERY_TOOLS]);
  assert.deepEqual(notifies, []);

  const result = (await eventHandlers.get("before_agent_start")?.at(-1)?.(
    { systemPrompt: "base", systemPromptOptions: {} },
    {},
  )) as { systemPrompt?: string } | undefined;
  assert.match(result?.systemPrompt ?? "", /<teach>/);

  await eventHandlers.get("agent_settled")?.at(-1)?.({}, {});
  assert.equal(getMode(), "plan");
});

test("tab during teach restores cycle without advancing", async () => {
  const { commands, entries, eventHandlers, shortcuts } = createPi();
  await eventHandlers.get("session_start")?.at(-1)?.({}, emptyCtx);
  const tab = shortcuts.get("tab");
  const teach = commands.get("teach");
  assert.ok(tab);
  assert.ok(teach);

  tab.handler();
  assert.equal(getMode(), "build");

  await teach.handler("why is this layered", {
    isIdle: () => true,
    ui: { notify: () => {} },
  });
  assert.equal(getMode(), "teach");

  tab.handler();
  assert.equal(getMode(), "build");
  assert.deepEqual(
    entries.map((entry) => entry.name),
    ["build"],
  );
});

test("/teach send failure restores cycle", async () => {
  const { commands, eventHandlers } = createPi({
    sendUserMessage: () => {
      throw new Error("nope");
    },
  });
  await eventHandlers.get("session_start")?.at(-1)?.({}, emptyCtx);
  const teach = commands.get("teach");
  assert.ok(teach);
  const notifies: string[] = [];
  await teach.handler("why is this layered", {
    isIdle: () => true,
    ui: { notify: (msg: string) => notifies.push(msg) },
  });

  assert.equal(getMode(), "plan");
  assert.deepEqual(notifies, ["Teach send failed"]);
});

test("/teach without a question or while busy does not send", async () => {
  const { commands, sent } = createPi();
  const teach = commands.get("teach");
  assert.ok(teach);
  const notifies: string[] = [];
  const ctx = {
    isIdle: () => true,
    ui: { notify: (msg: string) => notifies.push(msg) },
  };

  await teach.handler("  ", ctx);
  await teach.handler("later", {
    isIdle: () => false,
    ui: { notify: (msg: string) => notifies.push(msg) },
  });

  assert.deepEqual(sent, []);
  assert.equal(getMode(), "plan");
  assert.deepEqual(notifies, ["Usage: /teach <question>", "Agent is busy"]);
});
