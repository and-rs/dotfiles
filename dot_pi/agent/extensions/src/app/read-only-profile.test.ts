import assert from "node:assert/strict";
import test from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import registerApp from "./index.ts";
import { DISCOVERY_TOOLS } from "./modes.ts";

type EventHandler = (...args: unknown[]) => unknown;

test("teach mode restores discovery tools on session start and tree", async () => {
  const registeredTools: string[] = [];
  const activeToolSets: string[][] = [];
  const eventHandlers = new Map<string, EventHandler[]>();
  const pi = {
    registerTool(tool: { name: string }) {
      registeredTools.push(tool.name);
    },
    registerCommand() {},
    registerEntryRenderer() {},
    registerShortcut() {},
    appendEntry() {},
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

  assert.deepEqual(registeredTools, [...DISCOVERY_TOOLS]);

  const sessionStart = eventHandlers.get("session_start")?.at(-1);
  const sessionTree = eventHandlers.get("session_tree")?.at(-1);
  assert.ok(sessionStart);
  assert.ok(sessionTree);

  const ctx = {
    hasUI: false,
    sessionManager: { getEntries: () => [] },
  };
  await sessionStart?.({}, ctx);
  await sessionTree?.({}, ctx);

  assert.deepEqual(activeToolSets, [[...DISCOVERY_TOOLS], [...DISCOVERY_TOOLS]]);
});
