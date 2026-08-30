import assert from "node:assert/strict";
import test from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import registerApp from "./index.ts";
import { READ_ONLY_MODEL_TOOL_NAMES } from "./read-only-profile.ts";

type EventHandler = (...args: unknown[]) => unknown;

test("read-only profile exposes and restores only registered discovery tools", async () => {
  const registeredTools: string[] = [];
  const activeToolSets: string[][] = [];
  const eventHandlers = new Map<string, EventHandler[]>();
  const pi = {
    registerTool(tool: { name: string }) {
      registeredTools.push(tool.name);
    },
    registerCommand() {},
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

  assert.deepEqual(registeredTools, [...READ_ONLY_MODEL_TOOL_NAMES]);

  const sessionStart = eventHandlers.get("session_start")?.at(-1);
  const sessionTree = eventHandlers.get("session_tree")?.at(-1);
  assert.ok(sessionStart);
  assert.ok(sessionTree);

  await sessionStart?.({}, {});
  await sessionTree?.({}, {});

  assert.deepEqual(activeToolSets, [
    [...READ_ONLY_MODEL_TOOL_NAMES],
    [...READ_ONLY_MODEL_TOOL_NAMES],
  ]);
});
