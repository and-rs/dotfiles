import { dirname } from "node:path";
import { mkdir, writeFile } from "node:fs/promises";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import {
  HashlineMismatchError,
  applyHashlineJsonEdits,
  computeHashlineSnapshotId,
  formatHashLines,
  formatSnapshotStaleError,
  parseHashlineJsonEditParams,
} from "./hashline/index";
import { buildEditDiff, pathExists, renderDiffResult } from "./diff.ts";
import { ensureCreatablePathInCwd, ensureExistingPathInCwd, ensureReadablePath, readTextFile } from "./paths.ts";
import { registerBlockedFileTool } from "./renderers.ts";
import { detectLineEnding, normalizeToLf, restoreLineEndings } from "./text.ts";
import { AUTO_FULL_FILE_LINES, type CreateFileParams, type ReadParams } from "./types.ts";

type ReadRangeDetails = {
  kind: "range";
  path: string;
  absolutePath: string;
  snapshotId: string;
  startLine: number;
  endLine: number;
  totalLines: number;
  segment?: string;
};

type SegmentOption = {
  label: string;
  startLine: number;
  endLine: number;
  lineCount: number;
  preview: string;
};

type ReadMapDetails = {
  kind: "map";
  path: string;
  snapshotId: string;
  totalLines: number;
  segment?: string;
  options: SegmentOption[];
};

type HashlineToolResult = { details?: { diff?: string }; content: Array<{ type: string; text?: string }> };

function renderToolDiffResult(result: unknown, theme: Parameters<typeof renderDiffResult>[1], fallback: string): Text {
  return renderDiffResult(result as HashlineToolResult, theme, fallback);
}


function previewSegmentLine(line: string): string {
  const compact = line.trim().replace(/\s+/g, " ");
  if (!compact) return "(blank)";
  return compact.length <= 80 ? compact : `${compact.slice(0, 79)}…`;
}

function midpoint(startLine: number, endLine: number): number {
  return Math.floor((startLine + endLine) / 2);
}

function splitSegment(label: string, startLine: number, endLine: number): SegmentOption[] {
  if (startLine >= endLine) return [{ label, startLine, endLine, lineCount: endLine - startLine + 1, preview: "single line" }];
  const mid = midpoint(startLine, endLine);
  return [
    { label: `${label}A`, startLine, endLine: mid, lineCount: mid - startLine + 1, preview: "" },
    { label: `${label}B`, startLine: mid + 1, endLine, lineCount: endLine - mid, preview: "" },
  ];
}

function resolveSegment(totalLines: number, segment: string): { startLine: number; endLine: number } {
  let startLine = 1;
  let endLine = totalLines;
  for (const step of segment) {
    if (step !== "A" && step !== "B") throw new Error(`Invalid segment: ${segment}. Use labels like A, B, AA, or AB.`);
    if (startLine >= endLine) break;
    const mid = midpoint(startLine, endLine);
    if (step === "A") endLine = mid;
    else startLine = mid + 1;
  }
  return { startLine, endLine };
}

function buildSegmentOptions(lines: string[], startLine: number, endLine: number, baseLabel = ""): SegmentOption[] {
  return splitSegment(baseLabel, startLine, endLine).map((option) => {
    const first = previewSegmentLine(lines[option.startLine - 1] ?? "");
    const last = previewSegmentLine(lines[option.endLine - 1] ?? "");
    const preview = option.startLine === option.endLine ? first : `${first} … ${last}`;
    return { ...option, preview };
  });
}

function formatSegmentMap(path: string, totalLines: number, options: SegmentOption[], segment?: string): string {
  const title = segment ? `segment ${segment}` : "file";
  return [
    `${path}: ${totalLines} lines`,
    `${title} too large for whole-file read`,
    "choose segment:",
    ...options.map((option) => `- ${option.label}: lines ${option.startLine}-${option.endLine} (${option.lineCount} lines) :: ${option.preview}`),
    "call hashline-read again with same path and chosen segment label",
    "re-read chosen segment before edit for fresh anchors",
  ].join("\n");
}

function renderReadRange(details: ReadRangeDetails, theme: Parameters<typeof renderDiffResult>[1]): Text {
  const range = `${details.startLine}-${details.endLine}`;
  const segment = details.segment ? ` segment ${details.segment}` : "";
  return new Text(theme.fg("dim", `${details.path}: read${segment} lines ${range}/${details.totalLines}`), 0, 0);
}

function renderReadMap(details: ReadMapDetails, theme: Parameters<typeof renderDiffResult>[1]): Text {
  const segment = details.segment ? ` segment ${details.segment}` : "";
  const labels = details.options.map((option) => option.label).join(", ");
  return new Text(theme.fg("dim", `${details.path}:${segment} choose segment ${labels} (${details.totalLines} total lines)`), 0, 0);
}

export function registerHashlineEditTools(pi: ExtensionAPI): void {
  registerBlockedFileTool(pi, "read");
  registerBlockedFileTool(pi, "edit");
  registerBlockedFileTool(pi, "write");

  pi.registerTool({
    name: "hashline-read",
    label: "Hashline Read",
    description: "Read a text file with hashline anchors in each line. Small files return whole body; huge files return simple binary segment choices.",
    promptSnippet: "Read file content with line+hash anchors before hashline edits.",
    promptGuidelines: [
      "Use hashline-read before hashline-edit.",
      "Small files return whole body. Huge files return segment labels like A or B so you avoid line math.",
      "Re-read chosen file or chosen segment right before edit for fresh anchors.",
      "Use anchor tokens only, e.g. 1gs, not full read lines like 1gs|text.",
      "hashline-read may inspect text files under cwd or $HOME; hashline-edit and file-create stay cwd-bound.",
    ],
    parameters: Type.Object({
      path: Type.String({ description: "Path to the file to read" }),
      segment: Type.Optional(Type.String({ description: "Binary segment label like A, B, AA, or AB for huge files" })),
    }),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = params as ReadParams;
      const absolutePath = await ensureReadablePath(ctx.cwd, args.path);
      const source = await readTextFile(absolutePath);
      if (!source.exists) throw new Error(`File not found: ${args.path}`);
      const normalized = normalizeToLf(source.text);
      const snapshotId = computeHashlineSnapshotId(normalized);
      const allLines = normalized.split("\n");
      const totalLines = allLines.length;
      const segment = typeof args.segment === "string" && args.segment.trim() ? args.segment.trim().toUpperCase() : undefined;
      const target = segment ? resolveSegment(totalLines, segment) : { startLine: 1, endLine: totalLines };
      const targetLineCount = target.endLine - target.startLine + 1;
      if (targetLineCount <= AUTO_FULL_FILE_LINES) {
        const slice = allLines.slice(target.startLine - 1, target.endLine);
        const body = [`snapshotId: ${snapshotId}`, formatHashLines(slice.join("\n"), target.startLine)].join("\n");
        return {
          content: [{ type: "text", text: body }],
          details: { kind: "range", path: args.path, absolutePath, snapshotId, startLine: target.startLine, endLine: target.endLine, totalLines, segment } satisfies ReadRangeDetails,
        };
      }
      const options = buildSegmentOptions(allLines, target.startLine, target.endLine, segment ?? "");
      return {
        content: [{ type: "text", text: [`snapshotId: ${snapshotId}`, formatSegmentMap(args.path, totalLines, options, segment)].join("\n") }],
        details: { kind: "map", path: args.path, snapshotId, totalLines, segment, options } satisfies ReadMapDetails,
      };
    },
    renderResult(result, _options, theme) {
      const details = result.details as ReadRangeDetails | ReadMapDetails | undefined;
      if (!details) return new Text(theme.fg("dim", "hashline-read"), 0, 0);
      return details.kind === "range" ? renderReadRange(details, theme) : renderReadMap(details, theme);
    },
  });

  pi.registerTool({
    name: "file-create",
    label: "File Create",
    description: "Create a new text file. Refuses to overwrite existing files. Returns only a diff.",
    promptSnippet: "Create new files with file-create. Use hashline-edit only for existing-file edits.",
    parameters: Type.Object({
      path: Type.String({ description: "Path to new file. Must be inside cwd." }),
      content: Type.String({ description: "Complete UTF-8 file content." }),
    }),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = params as CreateFileParams;
      const absolutePath = await ensureCreatablePathInCwd(ctx.cwd, args.path);
      return withFileMutationQueue(absolutePath, async () => {
        if (await pathExists(absolutePath)) throw new Error(`File already exists: ${args.path}. Use hashline-read then hashline-edit.`);
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

  pi.registerTool({
    name: "hashline-edit",
    label: "Hashline Edit",
    description: "Apply strict JSON hashline edits to one existing file with snapshot and anchor validation.",
    promptSnippet: "Apply line-anchored hashline edits using strict JSON ops.",
    promptGuidelines: [
      "Use hashline-read first and copy the latest snapshotId.",
      "hashline-edit takes JSON fields: path, snapshotId, edits.",
      "One file per call. Do not edit multiple files in one hashline-edit call.",
      "Use anchor tokens only, e.g. 1gs, not full read lines like 1gs|text.",
      "Supported ops: replace, delete, insert_before, insert_after.",
      "replace/delete use start and end anchors. insert_before/insert_after use anchor.",
      "Replacement or inserted content goes in lines: string[]. Each array item is one output line; no embedded newlines.",
      "All edits validate before write and apply bottom-up. Overlapping ranges fail with no partial write.",
      "On snapshot_stale or anchor mismatch, retry with fresh anchors from the error or run hashline-read again.",
      "hashline-edit stays cwd-bound; start pi in target repo before editing another repo.",
    ],
    parameters: Type.Object({
      path: Type.String({ description: "Existing file path. Must be inside cwd." }),
      snapshotId: Type.String({ description: "snapshotId from the latest hashline-read for this file." }),
      edits: Type.Array(
        Type.Object({
          op: Type.Union([
            Type.Literal("replace"),
            Type.Literal("delete"),
            Type.Literal("insert_before"),
            Type.Literal("insert_after"),
          ]),
          start: Type.Optional(Type.String({ description: "Start anchor for replace/delete." })),
          end: Type.Optional(Type.String({ description: "End anchor for replace/delete." })),
          anchor: Type.Optional(Type.String({ description: "Target anchor for insert_before/insert_after." })),
          lines: Type.Optional(Type.Array(Type.String({ description: "One output line per string; no embedded newlines." }))),
        }),
        { description: "Strict JSON edit operations for one file." },
      ),
    }),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = parseHashlineJsonEditParams(params);
      const absolutePath = await ensureExistingPathInCwd(ctx.cwd, args.path);
      const result = await withFileMutationQueue(absolutePath, async () => {
        const source = await readTextFile(absolutePath);
        if (!source.exists) throw new Error(`File not found: ${args.path}. Use file-create for new files.`);
        const ending = detectLineEnding(source.text);
        const normalized = normalizeToLf(source.text);
        const currentSnapshotId = computeHashlineSnapshotId(normalized);
        const currentLines = normalized.split("\n");
        if (args.snapshotId !== currentSnapshotId) {
          throw new Error(formatSnapshotStaleError(args.path, args.snapshotId, currentSnapshotId, currentLines, args.edits));
        }
        let applied;
        try {
          applied = applyHashlineJsonEdits(normalized, args.edits);
        } catch (error) {
          if (error instanceof HashlineMismatchError) throw new Error(error.displayMessage);
          throw error;
        }
        const after = restoreLineEndings(applied.lines, ending);
        if (applied.changed) await writeFile(absolutePath, after, "utf8");
        return { editedFile: { path: absolutePath, before: source.text, after, changed: applied.changed }, detail: { path: args.path, changed: applied.changed } };
      });
      const diff = await buildEditDiff(ctx.cwd, [result.editedFile]);
      return { content: [{ type: "text", text: diff }], details: { files: [result.detail], diff } };
    },
    renderResult(result, _options, theme) {
      return renderToolDiffResult(result, theme, "No changes.");
    },
  });
}