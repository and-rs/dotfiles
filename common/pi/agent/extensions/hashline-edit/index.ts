import { mkdtemp, mkdir, readFile, realpath, rm, stat, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { dirname, isAbsolute, relative, resolve } from "node:path";
import { spawn } from "node:child_process";

import { type ExtensionAPI, withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

import { HashlineMismatchError, applyHashlineEdits, formatHashLines, parseHashlineWithWarnings, splitHashlineInputs } from "./hashline/index";
import type { HashlineSnapshot } from "./hashline/types";

type ReadParams = {
  path: string;
  offset?: number;
  limit?: number;
};

type EditParams = {
  input: string;
  path?: string;
  autoDropPureInsertDuplicates?: boolean;
};

type CreateFileParams = {
  path: string;
  content: string;
};

const DEFAULT_READ_LIMIT = 300;
const MAX_READ_LIMIT = 2000;
const READ_TRUNCATION_NOTICE = (start: number, end: number, total: number): string =>
  `[Showing lines ${start}-${end} of ${total}. Use :L${end + 1} to continue]`;
const HOME_DIR = resolve(homedir());
const MAX_TEXT_FILE_BYTES = 10 * 1024 * 1024;

const snapshots = new Map<string, HashlineSnapshot>();

function normalizeToolPathInput(candidatePath: string): string {
  const trimmed = candidatePath.trim();
  return trimmed.startsWith("@") && trimmed.length > 1 ? trimmed.slice(1) : candidatePath;
}

function resolveToolPath(cwd: string, candidatePath: string): string {
  const normalized = normalizeToolPathInput(candidatePath);
  return isAbsolute(normalized) ? resolve(normalized) : resolve(cwd, normalized);
}

function isPathInRoot(root: string, candidatePath: string): boolean {
  const rel = relative(resolve(root), candidatePath);
  return rel === "" || (!rel.startsWith("..") && !isAbsolute(rel));
}

async function realpathIfExists(path: string): Promise<string | null> {
  try {
    return await realpath(path);
  } catch (error) {
    const nodeError = error as NodeJS.ErrnoException;
    if (nodeError.code === "ENOENT") return null;
    throw error;
  }
}

async function findExistingAncestor(path: string): Promise<string> {
  let current = dirname(path);
  while (true) {
    const resolved = await realpathIfExists(current);
    if (resolved) return resolved;
    const parent = dirname(current);
    if (parent === current) return current;
    current = parent;
  }
}

function assertPathInCwd(cwd: string, candidatePath: string, absolutePath: string): void {
  if (!isPathInRoot(cwd, absolutePath)) {
    throw new Error(`Path outside cwd: ${candidatePath}. Start pi in target repo before editing or creating files. Current cwd: ${cwd}`);
  }
}

async function ensureExistingPathInCwd(cwd: string, candidatePath: string): Promise<string> {
  const absolute = resolveToolPath(cwd, candidatePath);
  assertPathInCwd(cwd, candidatePath, absolute);
  const resolved = await realpathIfExists(absolute);
  if (resolved) assertPathInCwd(cwd, candidatePath, resolved);
  return absolute;
}

async function ensureCreatablePathInCwd(cwd: string, candidatePath: string): Promise<string> {
  const absolute = resolveToolPath(cwd, candidatePath);
  assertPathInCwd(cwd, candidatePath, absolute);
  const existing = await realpathIfExists(absolute);
  if (existing) assertPathInCwd(cwd, candidatePath, existing);
  const ancestor = await findExistingAncestor(absolute);
  assertPathInCwd(cwd, candidatePath, ancestor);
  return absolute;
}

async function ensureReadablePath(cwd: string, candidatePath: string): Promise<string> {
  const absolute = resolveToolPath(cwd, candidatePath);
  const resolved = (await realpathIfExists(absolute)) ?? absolute;
  if (isPathInRoot(cwd, resolved) || isPathInRoot(HOME_DIR, resolved)) return absolute;
  throw new Error(`Path outside allowed read roots: ${candidatePath}. hashline_read allows current cwd (${cwd}) and $HOME (${HOME_DIR}). Start pi in target repo or read a file under $HOME.`);
}

function getSnapshot(path: string): HashlineSnapshot {
  const existing = snapshots.get(path);
  if (existing) return existing;
  const created: HashlineSnapshot = { lines: new Map<number, string>() };
  snapshots.set(path, created);
  return created;
}

function rememberRange(path: string, startLine: number, lines: string[]): void {
  const snapshot = getSnapshot(path);
  for (let i = 0; i < lines.length; i++) {
    snapshot.lines.set(startLine + i, lines[i]);
  }
}


function detectLineEnding(text: string): "\n" | "\r\n" {
  return text.includes("\r\n") ? "\r\n" : "\n";
}

function normalizeToLf(text: string): string {
  return text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
}

function restoreLineEndings(text: string, ending: "\n" | "\r\n"): string {
  if (ending === "\n") return text;
  return text.replace(/\n/g, "\r\n");
}

async function pathExists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch (error) {
    const nodeError = error as NodeJS.ErrnoException;
    if (nodeError.code === "ENOENT") return false;
    throw error;
  }
}

function looksBinary(buffer: Buffer): boolean {
  const sampleLength = Math.min(buffer.length, 8192);
  for (let i = 0; i < sampleLength; i++) {
    if (buffer[i] === 0) return true;
  }
  return false;
}

async function readTextFile(path: string): Promise<{ exists: boolean; text: string }> {
  try {
    const info = await stat(path);
    if (!info.isFile()) throw new Error(`Not a file: ${path}`);
    if (info.size > MAX_TEXT_FILE_BYTES) {
      throw new Error(`File too large for hashline tools: ${path} (${info.size} bytes, max ${MAX_TEXT_FILE_BYTES})`);
    }
    const buffer = await readFile(path);
    if (looksBinary(buffer)) throw new Error(`Binary file not supported by hashline tools: ${path}`);
    return { exists: true, text: buffer.toString("utf8") };
  } catch (error) {
    const nodeError = error as NodeJS.ErrnoException;
    if (nodeError.code === "ENOENT") return { exists: false, text: "" };
    throw error;
  }
}

function mergeWarnings(parseWarnings: string[], applyWarnings?: string[]): string[] {
  if (!applyWarnings || applyWarnings.length === 0) return parseWarnings;
  return [...parseWarnings, ...applyWarnings];
}

function runCommand(command: string, args: string[], options: { cwd?: string; input?: string } = {}): Promise<{ stdout: string; stderr: string; code: number }> {
  return new Promise((resolveCommand, reject) => {
    const child = spawn(command, args, { cwd: options.cwd, stdio: [options.input === undefined ? "ignore" : "pipe", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk: string) => {
      stderr += chunk;
    });
    child.on("error", reject);
    child.on("close", (code) => resolveCommand({ stdout, stderr, code: code ?? 0 }));

    if (options.input !== undefined && child.stdin) {
      child.stdin.end(options.input);
    }
  });
}

async function hasDelta(): Promise<boolean> {
  try {
    const result = await runCommand("delta", ["--version"]);
    return result.code === 0;
  } catch {
    return false;
  }
}

async function colorizeDiff(diff: string): Promise<string> {
  if (!diff.trim() || !(await hasDelta())) {
    return diff;
  }

  try {
    const result = await runCommand("delta", ["--paging=never"], { input: diff });
    return result.code === 0 && result.stdout.trim() ? result.stdout : diff;
  } catch {
    return diff;
  }
}

async function gitDiff(cwd: string, paths: string[]): Promise<string> {
  const relativePaths = paths.map((path) => relative(cwd, path));
  const result = await runCommand("git", ["diff", "--no-ext-diff", "--", ...relativePaths], { cwd });
  return result.code === 0 ? result.stdout : "";
}

function rewriteNoIndexHeader(diff: string, path: string, beforePath: string, afterPath: string): string {
  const rel = path.replace(/^\/+/, "");
  return diff
    .replaceAll(beforePath, `a/${rel}`)
    .replaceAll(afterPath, `b/${rel}`)
    .replace(/^diff --git a\/.* b\/.*$/m, `diff --git a/${rel} b/${rel}`);
}

async function noIndexDiff(cwd: string, file: { path: string; before: string; after: string }): Promise<string> {
  const tempDir = await mkdtemp(resolve(tmpdir(), "pi-hashline-diff-"));
  const beforePath = resolve(tempDir, "before");
  const afterPath = resolve(tempDir, "after");

  try {
    await writeFile(beforePath, file.before, "utf8");
    await writeFile(afterPath, file.after, "utf8");
    const result = await runCommand("git", ["diff", "--no-index", "--", beforePath, afterPath], { cwd });
    return rewriteNoIndexHeader(result.stdout || result.stderr, relative(cwd, file.path), beforePath, afterPath);
  } finally {
    await rm(tempDir, { force: true, recursive: true });
  }
}

async function buildEditDiff(cwd: string, files: Array<{ path: string; before: string; after: string; changed: boolean }>): Promise<string> {
  const changedFiles = files.filter((file) => file.changed);
  if (changedFiles.length === 0) {
    return "No changes.";
  }

  const fromGit = await gitDiff(cwd, changedFiles.map((file) => file.path));
  if (fromGit.trim()) {
    return colorizeDiff(fromGit);
  }

  const fallbackDiffs = await Promise.all(changedFiles.map((file) => noIndexDiff(cwd, file)));
  const combined = fallbackDiffs.filter((diff) => diff.trim()).join("\n");
  return colorizeDiff(combined || "No diff available.");
}

function blockedToolMessage(toolName: string): string {
  return `Tool "${toolName}" is disabled. Use hashline_read for file reads, hashline_edit for file edits, and file_create for new files.`;
}

function registerBlockedFileTool(pi: ExtensionAPI, name: "read" | "edit" | "write"): void {
  pi.registerTool({
    name,
    label: `${name} disabled`,
    description: blockedToolMessage(name),
    promptSnippet: blockedToolMessage(name),
    parameters: Type.Object({}),
    execute: async () => {
      throw new Error(blockedToolMessage(name));
    },
    renderResult(_result, _options, theme) {
      return new Text(theme.fg("error", blockedToolMessage(name)), 0, 0);
    },
  });
}

export default function hashlineEditExtension(pi: ExtensionAPI) {
  pi.on("session_start", () => {
    const api = pi as unknown as {
      getActiveTools?: () => string[];
      setActiveTools?: (toolNames: string[]) => void;
    };
    const active = typeof api.getActiveTools === "function" ? api.getActiveTools() : [];
    const filtered = active.filter((name) => name !== "edit" && name !== "write" && name !== "read");
    const next = Array.from(new Set([...filtered, "hashline_read", "hashline_edit", "file_create"]));
    if (typeof api.setActiveTools === "function") {
      api.setActiveTools(next);
    }
  });

  registerBlockedFileTool(pi, "read");
  registerBlockedFileTool(pi, "edit");
  registerBlockedFileTool(pi, "write");

  pi.registerTool({
    name: "hashline_read",
    label: "Hashline Read",
    description: "Read a text file with hashline anchors in each line. Paths may be inside cwd or $HOME.",
    promptSnippet: "Read file content with line+hash anchors before hashline edits.",
    promptGuidelines: [
      "Use hashline_read before hashline_edit.",
      "Use anchor tokens only, e.g. 1gs, not full read lines like 1gs|text.",
      "hashline_read may inspect text files under cwd or $HOME; hashline_edit and file_create stay cwd-bound.",
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
      if (!source.exists) {
        throw new Error(`File not found: ${args.path}`);
      }

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

      return {
        content: [{ type: "text", text: `${body}${suffix}` }],
        details: {
          path: args.path,
          absolutePath,
          startLine,
          endLine,
          totalLines: allLines.length,
          truncated,
        },
      };
    },
    renderResult(result, _options, theme) {
      const details = result.details as { path?: string; startLine?: number; endLine?: number; totalLines?: number; truncated?: boolean } | undefined;
      if (!details) {
        return new Text(theme.fg("dim", "hashline_read"), 0, 0);
      }
      const range = `${details.startLine ?? "?"}-${details.endLine ?? "?"}`;
      const suffix = details.truncated ? " truncated" : "";
      return new Text(theme.fg("dim", `${details.path ?? "file"}: read lines ${range}/${details.totalLines ?? "?"}${suffix}`), 0, 0);
    },
  });

  pi.registerTool({
    name: "file_create",
    label: "File Create",
    description: "Create a new text file. Refuses to overwrite existing files. Returns only a diff.",
    promptSnippet: "Create new files with file_create. Use hashline_edit only for existing-file edits.",
    parameters: Type.Object({
      path: Type.String({ description: "Path to new file. Must be inside cwd." }),
      content: Type.String({ description: "Complete UTF-8 file content." }),
    }),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = params as CreateFileParams;
      const absolutePath = await ensureCreatablePathInCwd(ctx.cwd, args.path);
      return withFileMutationQueue(absolutePath, async () => {
        if (await pathExists(absolutePath)) {
          throw new Error(`File already exists: ${args.path}. Use hashline_read then hashline_edit.`);
        }

        await mkdir(dirname(absolutePath), { recursive: true });
        await writeFile(absolutePath, args.content, "utf8");
        rememberRange(absolutePath, 1, normalizeToLf(args.content).split("\n"));

        const diff = await buildEditDiff(ctx.cwd, [{ path: absolutePath, before: "", after: args.content, changed: true }]);
        return {
          content: [{ type: "text", text: diff }],
          details: { path: args.path, diff },
        };
      });
    },
    renderResult(result, _options, theme) {
      const details = result.details as { diff?: string } | undefined;
      const diff = details?.diff ?? result.content.find((content) => content.type === "text")?.text ?? "";
      return new Text(diff || theme.fg("dim", "No diff available."), 0, 0);
    },
  });

  pi.registerTool({
    name: "hashline_edit",
    label: "Hashline Edit",
    description: "Apply hashline patch sections (@@ path + <|+|-|= ops) with strict anchor validation.",
    promptSnippet: "Apply line-anchored hashline edits with strict mismatch detection.",
    promptGuidelines: [
      "Use op lines as OP SPACE ANCHOR, e.g. = 1gs..1gs, not =1gs|text.",
      "Use anchors only, e.g. 1gs, not full read lines like 1gs|text.",
      "Delete and replace require explicit ranges, e.g. - 1gs..1gs or = 1gs..1gs.",
      "Payload lines start with the edit separator, default ~.",
      "hashline_edit stays cwd-bound; start pi in target repo before editing another repo.",
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
          if (!source.exists) {
            throw new Error(`File not found: ${section.path}. Use file_create for new files.`);
          }
          const ending = detectLineEnding(source.text);
          const normalized = normalizeToLf(source.text);
          const { edits, warnings: parseWarnings } = parseHashlineWithWarnings(section.diff);

          let applied;
          try {
            applied = applyHashlineEdits(normalized, edits, {
              autoDropPureInsertDuplicates: args.autoDropPureInsertDuplicates,
            });
          } catch (error) {
            if (error instanceof HashlineMismatchError) {
              throw new Error(error.displayMessage);
            }
            throw error;
          }

          const changed = applied.lines !== normalized;
          const warnings = mergeWarnings(parseWarnings, applied.warnings);
          const after = restoreLineEndings(applied.lines, ending);

          if (changed) {
            await writeFile(absolutePath, after, "utf8");
            rememberRange(absolutePath, 1, applied.lines.split("\n"));
          }

          return {
            editedFile: {
              path: absolutePath,
              before: source.text,
              after,
              changed,
            },
            detail: { path: section.path, changed, warnings },
          };
        });

        editedFiles.push(result.editedFile);
        details.push(result.detail);
      }

      const diff = await buildEditDiff(ctx.cwd, editedFiles);
      return {
        content: [{ type: "text", text: diff }],
        details: { files: details, diff },
      };
    },
    renderResult(result, _options, theme) {
      const details = result.details as { diff?: string } | undefined;
      const diff = details?.diff ?? result.content.find((content) => content.type === "text")?.text ?? "";
      return new Text(diff || theme.fg("dim", "No changes."), 0, 0);
    },
  });
}
