import assert from "node:assert/strict";
import test from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import registerApp from "./index.ts";
import { DISCOVERY_TOOLS, getMode, resetModes } from "./modes.ts";

type EventHandler = (...args: unknown[]) => unknown;

const BUILD_TOOLS = [...DISCOVERY_TOOLS, "bash", "edit", "write", "quickfix"];

const emptyCtx = {
  hasUI: false,
  sessionManager: { getEntries: () => [] },
};

function idleShortcutCtx(notify: (message: string) => void = () => undefined) {
  return {
    isIdle: () => true,
    ui: { notify },
  };
}

async function emitToolCall(
  eventHandlers: Map<string, EventHandler[]>,
  event: { toolName: string; input: Record<string, unknown> },
) {
  const handlers = eventHandlers.get("tool_call") ?? [];
  for (const handler of handlers) {
    const result = await handler(event);
    if (result && typeof result === "object" && "block" in result) {
      return result;
    }
  }
  return undefined;
}

function createPi(opts?: { sendUserMessage?: (text: string) => unknown }) {
  resetModes();
  const registeredTools: string[] = [];
  const activeToolSets: string[][] = [];
  const sent: string[] = [];
  const entries: Array<{ name?: string }> = [];
  const commands = new Map<string, { handler: EventHandler }>();
  const eventHandlers = new Map<string, EventHandler[]>();
  const shortcuts = new Map<string, { handler: EventHandler }>();
  const pi = {
    registerTool(tool: { name: string }) {
      registeredTools.push(tool.name);
    },
    registerCommand(name: string, spec: { handler: EventHandler }) {
      commands.set(name, spec);
    },
    registerEntryRenderer() {
      return undefined;
    },
    registerShortcut(name: string, spec: { handler: EventHandler }) {
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

test("secret paths are blocked before file access", async () => {
  const { eventHandlers } = createPi();

  for (const toolName of ["read", "grep", "find", "write", "edit", "ls"]) {
    const result = await emitToolCall(eventHandlers, {
      toolName,
      input: { path: `nested/.env.local` },
    });
    assert.deepEqual(result, {
      block: true,
      reason: "Access to .env files is denied.",
    });
  }
  const bash = await emitToolCall(eventHandlers, {
    toolName: "bash",
    input: { command: "cat nested/.env" },
  });
  assert.deepEqual(bash, {
    block: true,
    reason: "Access to .env files is denied.",
  });
});

test("new session keeps write tools in the schema and defaults to plan", async () => {
  const { registeredTools, activeToolSets, eventHandlers } = createPi();

  assert.deepEqual(registeredTools, [
    "read-image",
    "quickfix",
    "web_search",
    "web_fetch",
  ]);

  const sessionStart = eventHandlers.get("session_start")?.at(-1);
  assert.ok(sessionStart);
  await sessionStart?.({}, emptyCtx);

  assert.equal(getMode(), "plan");
  assert.deepEqual(activeToolSets.at(-1), BUILD_TOOLS);
});

test("alt+m cycles plan and build only", async () => {
  const { activeToolSets, entries, eventHandlers, shortcuts } = createPi();
  const sessionStart = eventHandlers.get("session_start")?.at(-1);
  await sessionStart?.({}, emptyCtx);

  const cycle = shortcuts.get("alt+m");
  assert.ok(cycle);
  cycle.handler(idleShortcutCtx());
  assert.equal(getMode(), "build");
  assert.deepEqual(activeToolSets.at(-1), BUILD_TOOLS);
  assert.deepEqual(entries.at(-1), { name: "build" });

  cycle.handler(idleShortcutCtx());
  assert.equal(getMode(), "plan");
  assert.deepEqual(activeToolSets.at(-1), BUILD_TOOLS);
  assert.deepEqual(
    entries.map((entry) => entry.name),
    ["build", "plan"],
  );
});

test("plan blocks mutating tools without removing them from the schema", async () => {
  const { activeToolSets, eventHandlers } = createPi();
  await eventHandlers.get("session_start")?.at(-1)?.({}, emptyCtx);

  assert.deepEqual(activeToolSets.at(-1), BUILD_TOOLS);
  const blocked = await emitToolCall(eventHandlers, {
    toolName: "edit",
    input: { path: "flash.tmux" },
  });
  assert.deepEqual(blocked, {
    block: true,
    reason: "Plan mode is read-only. Switch to build to edit.",
  });
  const allowed = await emitToolCall(eventHandlers, {
    toolName: "read",
    input: { path: "flash.tmux" },
  });
  assert.equal(allowed, undefined);
});

test("build allows mutating tools", async () => {
  const { eventHandlers, shortcuts } = createPi();
  await eventHandlers.get("session_start")?.at(-1)?.({}, emptyCtx);
  shortcuts.get("alt+m")?.handler(idleShortcutCtx());

  assert.equal(getMode(), "build");
  const result = await emitToolCall(eventHandlers, {
    toolName: "edit",
    input: { path: "flash.tmux" },
  });
  assert.equal(result, undefined);
});

test("alt+m keeps the committed mode while the agent is busy", async () => {
  const { eventHandlers, shortcuts } = createPi();
  await eventHandlers.get("session_start")?.at(-1)?.({}, emptyCtx);

  const cycle = shortcuts.get("alt+m");
  assert.ok(cycle);
  const notifies: string[] = [];
  cycle.handler({
    isIdle: () => false,
    ui: { notify: (message: string) => notifies.push(message) },
  });

  assert.equal(getMode(), "plan");
  assert.deepEqual(notifies, ["Agent is busy"]);
});

test("a later session_start does not reset an active build mode", async () => {
  const { activeToolSets, eventHandlers, shortcuts } = createPi();
  const sessionStart = eventHandlers.get("session_start")?.at(-1);
  await sessionStart?.({}, emptyCtx);

  shortcuts.get("alt+m")?.handler(idleShortcutCtx());
  await sessionStart?.(
    {},
    {
      hasUI: false,
      sessionManager: {
        getEntries: () => [
          { type: "custom", customType: "agent-mode", data: { name: "plan" } },
        ],
      },
    },
  );

  assert.equal(getMode(), "build");
  assert.deepEqual(activeToolSets.at(-1), BUILD_TOOLS);
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
  assert.match(
    result?.systemPrompt ?? "",
    /<active-agent-mode>plan<\/active-agent-mode>/,
  );
  assert.match(result?.systemPrompt ?? "", /<plan>/);
  assert.match(
    result?.systemPrompt ?? "",
    /Stay in the current working directory/,
  );
  assert.deepEqual(activeToolSets.at(-1), BUILD_TOOLS);
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
  assert.match(
    result?.systemPrompt ?? "",
    /<active-agent-mode>plan<\/active-agent-mode>/,
  );
  assert.match(result?.systemPrompt ?? "", /<plan>/);
  assert.match(
    result?.systemPrompt ?? "",
    /Stay in the current working directory/,
  );
});

test("before_agent_start in build re-applies write tools", async () => {
  const { activeToolSets, eventHandlers, shortcuts } = createPi();
  await eventHandlers.get("session_start")?.at(-1)?.({}, emptyCtx);
  shortcuts.get("alt+m")?.handler(idleShortcutCtx());

  const result = (await eventHandlers.get("before_agent_start")?.at(-1)?.(
    {
      systemPrompt: "base",
      systemPromptOptions: {
        selectedTools: ["read", "grep"],
      },
    },
    {},
  )) as { systemPrompt?: string } | undefined;

  assert.equal(getMode(), "build");
  assert.deepEqual(activeToolSets.at(-1), BUILD_TOOLS);
  assert.match(
    result?.systemPrompt ?? "",
    /<active-agent-mode>build<\/active-agent-mode>/,
  );
  assert.match(result?.systemPrompt ?? "", /<build>/);
  assert.doesNotMatch(result?.systemPrompt ?? "", /You cannot edit/);
  assert.doesNotMatch(result?.systemPrompt ?? "", /<plan>/);
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
  assert.deepEqual(activeToolSets.at(-1), BUILD_TOOLS);
  assert.deepEqual(notifies, []);

  const result = (await eventHandlers.get("before_agent_start")?.at(-1)?.(
    { systemPrompt: "base", systemPromptOptions: {} },
    {},
  )) as { systemPrompt?: string } | undefined;
  assert.match(result?.systemPrompt ?? "", /<teach>/);

  await eventHandlers.get("agent_settled")?.at(-1)?.({}, {});
  assert.equal(getMode(), "plan");
});

test("alt+m during teach restores cycle without advancing", async () => {
  const { commands, entries, eventHandlers, shortcuts } = createPi();
  await eventHandlers.get("session_start")?.at(-1)?.({}, emptyCtx);
  const cycle = shortcuts.get("alt+m");
  const teach = commands.get("teach");
  assert.ok(cycle);
  assert.ok(teach);

  cycle.handler(idleShortcutCtx());
  assert.equal(getMode(), "build");

  await teach.handler("why is this layered", {
    isIdle: () => true,
    ui: { notify: () => undefined },
  });
  assert.equal(getMode(), "teach");

  cycle.handler(idleShortcutCtx());
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
