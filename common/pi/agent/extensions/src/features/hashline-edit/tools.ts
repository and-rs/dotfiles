import { dirname } from "node:path";
import { mkdir, writeFile } from "node:fs/promises";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { applyHashlineJsonEdits, parseHashlineToolParams, type HashlineApplyParams, type HashlineSegmentParams, type HashlineStageParams, type HashlineToolParams } from "./hashline/index.ts";
import { buildHashlineContext, type HashlineContextMap, type HashlineContextRange } from "./context.ts";
import { buildEditDiff, pathExists, renderDiffResult } from "./diff.ts";
import { ensureCreatablePathInCwd, ensureExistingPathInCwd, readTextFile } from "./paths.ts";
import { registerBlockedFileTool } from "./renderers.ts";
import { detectLineEnding, normalizeToLf, restoreLineEndings } from "./text.ts";
import { type CreateFileParams } from "./types.ts";

type HashlineToolResult = { details?: { diff?: string; kind?: string }; content: Array<{ type: string; text?: string }> };

type PendingHashlineFlow = {
  path: string;
  goal: string;
  mode: "await-segment" | "await-apply";
  segment?: string;
  segmentOptions?: string[];
  steerCount: number;
  applyFailures: number;
};

const MAX_STEER_COUNT = 8;
const MAX_APPLY_FAILURES = 1;
const STEER_CUSTOM_TYPE = "hashline-edit-steer";

function renderToolDiffResult(result: unknown, theme: Parameters<typeof renderDiffResult>[1], fallback: string): Text {
  return renderDiffResult(result as HashlineToolResult, theme, fallback);
}

function renderContextRange(details: HashlineContextRange, theme: Parameters<typeof renderDiffResult>[1]): Text {
  const range = `${details.startLine}-${details.endLine}`;
  const segment = details.segment ? ` segment ${details.segment}` : "";
  return new Text(theme.fg("dim", `${details.path}: staged edit context${segment} lines ${range}/${details.totalLines}`), 0, 0);
}

function renderContextMap(details: HashlineContextMap, theme: Parameters<typeof renderDiffResult>[1]): Text {
  const segment = details.segment ? ` segment ${details.segment}` : "";
  const labels = details.options.map((option) => option.label).join(", ");
  return new Text(theme.fg("dim", `${details.path}:${segment} staged edit choose segment ${labels} (${details.totalLines} total lines)`), 0, 0);
}

function isStageParams(args: HashlineToolParams): args is HashlineStageParams {
  return "goal" in args;
}

function isSegmentParams(args: HashlineToolParams): args is HashlineSegmentParams {
  return "segment" in args && !("goal" in args) && !("edits" in args);
}

function isApplyParams(args: HashlineToolParams): args is HashlineApplyParams {
  return "edits" in args;
}

function setPendingStatus(ui: { setStatus: (key: string, text: string | undefined) => void }, pending: PendingHashlineFlow | null): void {
  if (!pending) {
    ui.setStatus("hashline-edit-flow", undefined);
    return;
  }
  const step = pending.mode === "await-segment" ? "awaiting segment choice" : "awaiting edits";
  ui.setStatus("hashline-edit-flow", `hashline-edit staged ${pending.path} — ${step}`);
}

function clearPending(
  state: { current: PendingHashlineFlow | null },
  ui?: { setStatus: (key: string, text: string | undefined) => void },
): void {
  state.current = null;
  if (ui) setPendingStatus(ui, null);
}

function queueSteerMessage(pi: ExtensionAPI, pending: PendingHashlineFlow): boolean {
  pending.steerCount += 1;
  if (pending.steerCount > MAX_STEER_COUNT) return false;
  pi.sendMessage(
    {
      customType: STEER_CUSTOM_TYPE,
      content: buildSteerPrompt(pending),
      display: false,
    },
    { deliverAs: "steer" },
  );
  return true;
}

function isRecoverableApplyError(message: string): boolean {
  return message.startsWith("hashline-edit rejected: match_missing") || message.startsWith("hashline-edit rejected: match_ambiguous");
}

function buildSteerPrompt(pending: PendingHashlineFlow): string {
  if (pending.mode === "await-segment") {
    const labels = pending.segmentOptions?.join(", ") ?? "(see previous tool result)";
    return [
      `hashline-edit staged for path ${pending.path}.`,
      `Original goal: ${pending.goal}`,
      "Previous hashline-edit result returned segment choices.",
      `Call hashline-edit now with JSON: {"path":${JSON.stringify(pending.path)},"segment":"LABEL"}.`,
      `Allowed segment labels: ${labels}.`,
      "Use one label from immediately previous hashline-edit result.",
      "Do not send goal. Do not send edits. Do not answer with prose.",
    ].join("\n");
  }
  return [
    `hashline-edit staged for path ${pending.path}.`,
    `Original goal: ${pending.goal}`,
    pending.applyFailures > 0
      ? "Previous apply attempt failed. Use only fresh live context from immediately previous hashline-edit result."
      : "Fresh live context came from immediately previous hashline-edit result.",
    `Call hashline-edit now with JSON: {"path":${JSON.stringify(pending.path)},"edits":[...]}.`,
    "Do not send goal. Do not send segment. Do not answer with prose.",
  ].join("\n");
}

function buildPendingReason(pending: PendingHashlineFlow): string {
  if (pending.mode === "await-segment") {
    const labels = pending.segmentOptions?.join(", ") ?? "one returned label";
    return `hashline-edit is staged for ${pending.path}. Next call must be {"path":${JSON.stringify(pending.path)},"segment":"LABEL"} using ${labels}.`;
  }
  return `hashline-edit is staged for ${pending.path}. Next call must be {"path":${JSON.stringify(pending.path)},"edits":[...]}.`;
}

function stageFromDetails(
  path: string,
  goal: string,
  details: HashlineContextRange | HashlineContextMap,
  carry?: Pick<PendingHashlineFlow, "steerCount" | "applyFailures">,
): PendingHashlineFlow {
  if (details.kind === "map") {
    return {
      path,
      goal,
      mode: "await-segment",
      segment: details.segment,
      segmentOptions: details.options.map((option) => option.label),
      steerCount: carry?.steerCount ?? 0,
      applyFailures: carry?.applyFailures ?? 0,
    };
  }
  return {
    path,
    goal,
    mode: "await-apply",
    segment: details.segment,
    steerCount: carry?.steerCount ?? 0,
    applyFailures: carry?.applyFailures ?? 0,
  };
}

export function registerHashlineEditTools(pi: ExtensionAPI): void {
  registerBlockedFileTool(pi, "edit");
  registerBlockedFileTool(pi, "write");

  const pending = { current: null as PendingHashlineFlow | null };

  pi.on("session_start", (_event, ctx) => {
    clearPending(pending, ctx.ui);
  });

  pi.on("session_shutdown", (_event, ctx) => {
    clearPending(pending, ctx.ui);
  });

  pi.on("tool_call", (event) => {
    if (event.toolName !== "hashline-edit") return;
    let args: HashlineToolParams;
    try {
      args = parseHashlineToolParams(event.input);
    } catch {
      return;
    }
    if (!pending.current) {
      if (!isStageParams(args)) {
        return {
          block: true,
          reason: 'hashline-edit always starts with fresh live context. First call must be {"path":"...","goal":"..."}.',
        };
      }
      return;
    }
    if (args.path !== pending.current.path) {
      return {
        block: true,
        reason: `hashline-edit is staged for ${pending.current.path}. Finish or abandon that edit before starting another file.`,
      };
    }
    if (pending.current.mode === "await-segment") {
      if (!isSegmentParams(args)) return { block: true, reason: buildPendingReason(pending.current) };
      return;
    }
    if (!isApplyParams(args)) return { block: true, reason: buildPendingReason(pending.current) };
  });

  pi.registerTool({
    name: "file-create",
    label: "File Create",
    description: "Create a new text file. Refuses to overwrite existing files. Returns only a diff.",
    promptSnippet: "Create new files with file-create. Use hashline-edit for existing files.",
    parameters: Type.Object({
      path: Type.String({ description: "Path to new file. Must be inside cwd." }),
      content: Type.String({ description: "Complete UTF-8 file content." }),
    }),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = params as CreateFileParams;
      const absolutePath = await ensureCreatablePathInCwd(ctx.cwd, args.path);
      return withFileMutationQueue(absolutePath, async () => {
        if (await pathExists(absolutePath)) throw new Error(`File already exists: ${args.path}. Use hashline-edit for existing files.`);
        await mkdir(dirname(absolutePath), { recursive: true });
        await writeFile(absolutePath, args.content, "utf8");
        const diff = await buildEditDiff(ctx.cwd, [{ path: absolutePath, before: "", after: args.content, changed: true }]);
        return { content: [{ type: "text", text: diff }], details: { path: args.path, diff } };
      });
    },
    renderResult(result, _options, theme) {
      return renderToolDiffResult(result, theme, "No diff available.");
    },
  });

  const lineArray = Type.Array(Type.String({ description: "One output line per string; no embedded newlines." }), { minItems: 1 });
  const matchArray = Type.Array(Type.String({ description: "Exact current file lines that identify target block." }), { minItems: 1 });

  pi.registerTool({
    name: "hashline-edit",
    label: "Hashline Edit",
    description: "Edit one existing text file through staged fresh context, then strict JSON edits. Not for read-only file inspection.",
    promptSnippet: "Use hashline-edit only when editing an existing file. Start with {path, goal}, then follow staged instructions with same tool.",
    promptGuidelines: [
      'Do not use hashline-edit for read-only file inspection. Use read, code-search, or code-files instead.',
      'Every edit starts with {"path":"...","goal":"..."}. Do not send edits on first call.',
      'hashline-edit fetches fresh live context only to plan and apply edits.',
      'If hashline-edit returns segment choices, next call uses {"path":"...","segment":"A"}.',
      'After hashline-edit returns anchored context, next call uses {"path":"...","edits":[...]}.',
      'One file per call. Do not edit multiple files in one hashline-edit call.',
      'replace/delete use match: string[] with exact current file lines from fresh staged context.',
      'insert_before/insert_after use match: string[] to locate anchor block. insert_before inserts before first matched line. insert_after inserts after last matched line.',
      'Replacement or inserted content goes in lines: string[]. Each array item is one output line; no embedded newlines.',
      'All edits validate before write and apply bottom-up. Overlapping ranges fail with no partial write.',
      'Never rely on old non-hashline reads for edit targeting. Fresh staged hashline context wins.',
      'hashline-edit stays cwd-bound; start pi in target repo before editing another repo.',
    ],
    parameters: Type.Union([
      Type.Object({
        path: Type.String({ description: "Existing file path. Must be inside cwd." }),
        goal: Type.String({ description: "What change you want in this file. First hashline-edit call always uses goal." }),
      }),
      Type.Object({
        path: Type.String({ description: "Existing file path. Must be inside cwd." }),
        segment: Type.String({ description: "Segment label previously returned by hashline-edit, like A, B, AA, or AB." }),
      }),
      Type.Object({
        path: Type.String({ description: "Existing file path. Must be inside cwd." }),
        edits: Type.Array(
          Type.Union([
            Type.Object({ op: Type.Literal("replace"), match: matchArray, lines: lineArray }),
            Type.Object({ op: Type.Literal("delete"), match: matchArray }),
            Type.Object({ op: Type.Literal("insert_before"), match: matchArray, lines: lineArray }),
            Type.Object({ op: Type.Literal("insert_after"), match: matchArray, lines: lineArray }),
          ]),
          { description: "Strict JSON edit operations for one file after staged fresh context." },
        ),
      }),
    ]),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = parseHashlineToolParams(params);
      const absolutePath = await ensureExistingPathInCwd(ctx.cwd, args.path);

      if (isStageParams(args)) {
        const source = await readTextFile(absolutePath);
        if (!source.exists) throw new Error(`File not found: ${args.path}. Use file-create for new files.`);
        const normalized = normalizeToLf(source.text);
        const details = buildHashlineContext(args.path, normalized);
        pending.current = stageFromDetails(args.path, args.goal, details);
        setPendingStatus(ctx.ui, pending.current);
        ctx.ui.notify(`hashline-edit staged ${args.path}.`, "info");
        if (!queueSteerMessage(pi, pending.current)) {
          clearPending(pending, ctx.ui);
          throw new Error(`hashline-edit steer limit reached for ${args.path}. Start a new staged edit with a tighter goal.`);
        }
        return { content: [{ type: "text", text: details.body }], details };
      }

      if (isSegmentParams(args)) {
        if (!pending.current || pending.current.path !== args.path) {
          throw new Error('hashline-edit is not staged for this file. Start with {"path":"...","goal":"..."}.');
        }
        if (pending.current.mode !== "await-segment") {
          throw new Error(buildPendingReason(pending.current));
        }
        const source = await readTextFile(absolutePath);
        if (!source.exists) throw new Error(`File not found: ${args.path}. Use file-create for new files.`);
        const normalized = normalizeToLf(source.text);
        const details = buildHashlineContext(args.path, normalized, args.segment);
        pending.current = stageFromDetails(args.path, pending.current.goal, details, {
          steerCount: pending.current.steerCount,
          applyFailures: pending.current.applyFailures,
        });
        setPendingStatus(ctx.ui, pending.current);
        ctx.ui.notify(`hashline-edit staged ${args.path}.`, "info");
        if (!queueSteerMessage(pi, pending.current)) {
          clearPending(pending, ctx.ui);
          throw new Error(`hashline-edit steer limit reached for ${args.path}. Start a new staged edit with a tighter goal.`);
        }
        return { content: [{ type: "text", text: details.body }], details };
      }

      if (!pending.current || pending.current.path !== args.path) {
        throw new Error('hashline-edit is not staged for this file. Start with {"path":"...","goal":"..."}.');
      }
      if (pending.current.mode !== "await-apply") {
        throw new Error(buildPendingReason(pending.current));
      }

      try {
        const result = await withFileMutationQueue(absolutePath, async () => {
          const source = await readTextFile(absolutePath);
          if (!source.exists) throw new Error(`File not found: ${args.path}. Use file-create for new files.`);
          const ending = detectLineEnding(source.text);
          const normalized = normalizeToLf(source.text);
          const applied = applyHashlineJsonEdits(args.path, normalized, args.edits);
          const after = restoreLineEndings(applied.lines, ending);
          if (applied.changed) await writeFile(absolutePath, after, "utf8");
          return { editedFile: { path: absolutePath, before: source.text, after, changed: applied.changed }, detail: { path: args.path, changed: applied.changed } };
        });
        clearPending(pending, ctx.ui);
        const diff = await buildEditDiff(ctx.cwd, [result.editedFile]);
        return { content: [{ type: "text", text: diff }], details: { files: [result.detail], diff } };
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        if (pending.current && isRecoverableApplyError(message) && pending.current.applyFailures < MAX_APPLY_FAILURES) {
          pending.current = {
            ...pending.current,
            applyFailures: pending.current.applyFailures + 1,
          };
          setPendingStatus(ctx.ui, pending.current);
          ctx.ui.notify(`hashline-edit apply failed for ${args.path}; revision steer queued.`, "warning");
          if (!queueSteerMessage(pi, pending.current)) {
            clearPending(pending, ctx.ui);
          }
        } else {
          clearPending(pending, ctx.ui);
        }
        throw error;
      }
    },
    renderResult(result, _options, theme) {
      const details = result.details as HashlineContextRange | HashlineContextMap | undefined;
      if (details?.kind === "range") return renderContextRange(details, theme);
      if (details?.kind === "map") return renderContextMap(details, theme);
      return renderToolDiffResult(result, theme, "No changes.");
    },
  });
}
