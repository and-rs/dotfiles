import { dirname } from "node:path";
import { mkdir, writeFile } from "node:fs/promises";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { HashlineMismatchError, applyHashlineEdits, formatHashLines, parseHashlineWithWarnings, splitHashlineInputs } from "./hashline/index";
import { buildEditDiff, pathExists, renderDiffResult } from "./diff.ts";
import { ensureCreatablePathInCwd, ensureExistingPathInCwd, ensureReadablePath, readTextFile, rememberRange } from "./paths.ts";
import { registerBlockedFileTool } from "./renderers.ts";
import { detectLineEnding, normalizeToLf, restoreLineEndings } from "./text.ts";
import { DEFAULT_READ_LIMIT, MAX_READ_LIMIT, READ_TRUNCATION_NOTICE, type CreateFileParams, type EditParams, type ReadParams } from "./types.ts";

function mergeWarnings(parseWarnings: string[], applyWarnings?: string[]): string[] {
  if (!applyWarnings || applyWarnings.length === 0) return parseWarnings;
  return [...parseWarnings, ...applyWarnings];
}

export function registerHashlineEditTools(pi: ExtensionAPI): void {
  registerBlockedFileTool(pi, "read");
  registerBlockedFileTool(pi, "edit");
  registerBlockedFileTool(pi, "write");

  pi.registerTool({
    name: "hashline-read",
    label: "Hashline Read",
    description: "Read a text file with hashline anchors in each line. Paths may be inside cwd or $HOME.",
    promptSnippet: "Read file content with line+hash anchors before hashline edits.",
    promptGuidelines: [
      "Use hashline-read before hashline-edit.",
      "Use anchor tokens only, e.g. 1gs, not full read lines like 1gs|text.",
      "hashline-read may inspect text files under cwd or $HOME; hashline-edit and file-create stay cwd-bound.",
      "If output is truncated, continue with :L<line> offset.",
    ],
    parameters: Type.Object({
      path: Type.String({ description: "Path to the file to read" }),
      offset: Type.Optional(Type.Integer({ minimum: 1, description: "Line number to start (1-indexed)" })),
      limit: Type.Optional(Type.Integer({ minimum: 1, maximum: MAX_READ_LIMIT, description: "Max lines to read" })),
    }),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = params as ReadParams;
      const absolutePath = await ensureReadablePath(ctx.cwd, args.path);
      const source = await readTextFile(absolutePath);
      if (!source.exists) throw new Error(`File not found: ${args.path}`);
      const normalized = normalizeToLf(source.text);
      const allLines = normalized.split("\n");
      const offset = typeof args.offset === "number" ? args.offset : 1;
      const limit = Math.min(typeof args.limit === "number" ? args.limit : DEFAULT_READ_LIMIT, MAX_READ_LIMIT);
      const startIndex = Math.max(0, offset - 1);
      const slice = allLines.slice(startIndex, startIndex + limit);
      const startLine = startIndex + 1;
      const endLine = startIndex + slice.length;
      rememberRange(absolutePath, startLine, slice);
      const body = formatHashLines(slice.join("\n"), startLine);
      const truncated = endLine < allLines.length;
      const suffix = truncated ? `\n\n${READ_TRUNCATION_NOTICE(startLine, endLine, allLines.length)}` : "";
      return { content: [{ type: "text", text: `${body}${suffix}` }], details: { path: args.path, absolutePath, startLine, endLine, totalLines: allLines.length, truncated } };
    },
    renderResult(result, _options, theme) {
      const details = result.details as { path?: string; startLine?: number; endLine?: number; totalLines?: number; truncated?: boolean } | undefined;
      if (!details) return new Text(theme.fg("dim", "hashline-read"), 0, 0);
      const range = `${details.startLine ?? "?"}-${details.endLine ?? "?"}`;
      const suffix = details.truncated ? " truncated" : "";
      return new Text(theme.fg("dim", `${details.path ?? "file"}: read lines ${range}/${details.totalLines ?? "?"}${suffix}`), 0, 0);
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
        rememberRange(absolutePath, 1, normalizeToLf(args.content).split("\n"));
        const diff = await buildEditDiff(ctx.cwd, [{ path: absolutePath, before: "", after: args.content, changed: true }]);
        return { content: [{ type: "text", text: diff }], details: { path: args.path, diff } };
      });
    },
    renderResult(result, _options, theme) {
      return renderDiffResult(result as { details?: { diff?: string }; content: Array<{ type: string; text?: string }> }, theme, "No diff available.");
    },
  });

  pi.registerTool({
    name: "hashline-edit",
    label: "Hashline Edit",
    description: "Apply hashline patch sections (@@ path + <|+|-|= ops) with strict anchor validation.",
    promptSnippet: "Apply line-anchored hashline edits with strict mismatch detection.",
    promptGuidelines: [
      "Use op lines as OP SPACE ANCHOR, e.g. = 1gs..1gs, not =1gs|text.",
      "Use anchors only, e.g. 1gs, not full read lines like 1gs|text.",
      "Delete and replace require explicit ranges, e.g. - 1gs..1gs or = 1gs..1gs.",
      "Payload lines start with the edit separator, default ~.",
      "hashline-edit stays cwd-bound; start pi in target repo before editing another repo.",
    ],
    parameters: Type.Object({
      input: Type.String({ description: "Hashline patch input. First non-blank line must be @@ PATH." }),
      path: Type.Optional(Type.String({ description: "Fallback path when input omits @@ PATH." })),
      autoDropPureInsertDuplicates: Type.Optional(Type.Boolean({ description: "Enable context-echo absorb for pure inserts." })),
    }),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = params as EditParams;
      const sections = splitHashlineInputs(args.input, { cwd: ctx.cwd, path: args.path });
      const editedFiles: Array<{ path: string; before: string; after: string; changed: boolean }> = [];
      const details: Array<{ path: string; changed: boolean; warnings: string[] }> = [];
      for (const section of sections) {
        const absolutePath = await ensureExistingPathInCwd(ctx.cwd, section.path);
        const result = await withFileMutationQueue(absolutePath, async () => {
          const source = await readTextFile(absolutePath);
          if (!source.exists) throw new Error(`File not found: ${section.path}. Use file-create for new files.`);
          const ending = detectLineEnding(source.text);
          const normalized = normalizeToLf(source.text);
          const { edits, warnings: parseWarnings } = parseHashlineWithWarnings(section.diff);
          let applied;
          try {
            applied = applyHashlineEdits(normalized, edits, { autoDropPureInsertDuplicates: args.autoDropPureInsertDuplicates });
          } catch (error) {
            if (error instanceof HashlineMismatchError) throw new Error(error.displayMessage);
            throw error;
          }
          const changed = applied.lines !== normalized;
          const warnings = mergeWarnings(parseWarnings, applied.warnings);
          const after = restoreLineEndings(applied.lines, ending);
          if (changed) {
            await writeFile(absolutePath, after, "utf8");
            rememberRange(absolutePath, 1, applied.lines.split("\n"));
          }
          return { editedFile: { path: absolutePath, before: source.text, after, changed }, detail: { path: section.path, changed, warnings } };
        });
        editedFiles.push(result.editedFile);
        details.push(result.detail);
      }
      const diff = await buildEditDiff(ctx.cwd, editedFiles);
      return { content: [{ type: "text", text: diff }], details: { files: details, diff } };
    },
    renderResult(result, _options, theme) {
      return renderDiffResult(result as { details?: { diff?: string }; content: Array<{ type: string; text?: string }> }, theme, "No changes.");
    },
  });
}
