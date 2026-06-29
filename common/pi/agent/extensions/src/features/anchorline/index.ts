import { spawn } from "node:child_process";
import { access, readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { isAbsolute, relative, resolve } from "node:path";
import { renderDeltaDiff } from "../delta-diff.ts";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

type AnchorlineShowParams = {
  path: string;
  start?: number;
  end?: number;
};

type AnchorlineEditParams = {
  path: string;
  patch: string;
};
const ANCHORLINE_BIN = resolve(homedir(), ".cargo/bin/anchorline");
const MAX_ANCHORLINE_SHOW_CHARS = 45_000;
let cachedAnchorlineHelp: string | undefined;

async function anchorlineHelp(): Promise<string> {
  if (cachedAnchorlineHelp) return cachedAnchorlineHelp;
  cachedAnchorlineHelp = (await runAnchorline(["--help"])).trim();
  return cachedAnchorlineHelp;
}

const activeEditPaths = new Set<string>();

function isInsideCwd(cwd: string, value: string): boolean {
  const absolute = resolve(cwd, value);
  const rel = relative(cwd, absolute);
  return rel.length === 0 || (!rel.startsWith("..") && !isAbsolute(rel));
}

function resolveEditPath(cwd: string, value: string): string {
  if (!isInsideCwd(cwd, value)) throw new Error(`Path must be inside cwd: ${value}`);
  return resolve(cwd, value);
}

async function pathExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

function runAnchorline(args: string[], input?: string): Promise<string> {
  return new Promise((resolveOutput, reject) => {
    const child = spawn(ANCHORLINE_BIN, args, { stdio: ["pipe", "pipe", "pipe"] });
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
    child.once("error", reject);
    child.once("close", (code) => {
      if (code === 0) {
        resolveOutput(stdout);
        return;
      }
      reject(new Error(stderr.trim() || `anchorline exited with code ${code ?? "unknown"}`));
    });
    if (input !== undefined) {
      child.stdin.end(input, "utf8");
    } else {
      child.stdin.end();
    }
  });
}

function anchorlineArgsForShow(path: string, start?: number, end?: number): string[] {
  const args = ["show", path];
  if (start !== undefined) args.push(String(start));
  if (end !== undefined) args.push(String(end));
  return args;
}

function trimAnchorlineOutput(output: string): { text: string; truncated: boolean } {
  if (output.length <= MAX_ANCHORLINE_SHOW_CHARS) return { text: output, truncated: false };
  return { text: "output trimmed; rerun anchorline-show with start/end.", truncated: true };
}

async function anchorlineError(error: unknown): Promise<Error> {
  const message = error instanceof Error ? error.message : String(error);
  if (message.toLowerCase().includes("patch grammar:")) return new Error(message);
  return new Error(`${message}${String.fromCharCode(10)}${String.fromCharCode(10)}${await anchorlineHelp()}`);
}

async function runShow(path: string, start?: number, end?: number): Promise<{ text: string; truncated: boolean }> {
  const output = await runAnchorline(anchorlineArgsForShow(path, start, end));
  return trimAnchorlineOutput(output);
}
export default function registerAnchorlineFeature(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "anchorline-help",
    label: "Anchorline Help",
    description: "Return concise anchorline grammar and workflow. Use when anchorline patch syntax or edit flow is unclear.",
    promptSnippet: "Use anchorline-help after anchorline syntax confusion instead of shelling anchorline --help.",
    parameters: Type.Object({}),
    execute: async () => ({ content: [{ type: "text", text: await anchorlineHelp() }], details: {} }),
    renderResult() { return new Text("anchorline help", 0, 0); },
  });

  pi.registerTool({
    name: "anchorline-show",
    label: "Anchorline Show",
    description: "Show anchored lines for existing file. Use immediately before anchorline-edit. Use start/end for large files.",
    promptSnippet: "Use anchorline-show before anchorline-edit; use start/end range when output trims.",
    parameters: Type.Object({
      path: Type.String({ description: "Existing file path. Must be inside cwd." }),
      start: Type.Optional(Type.Integer({ minimum: 1, description: "Optional 1-based inclusive start line for large files." })),
      end: Type.Optional(Type.Integer({ minimum: 1, description: "Optional 1-based inclusive end line for large files." })),
    }),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = params as AnchorlineShowParams;
      const absolutePath = resolveEditPath(ctx.cwd, args.path);
      if (!(await pathExists(absolutePath))) {
        throw new Error(`File not found: ${args.path}. Use file-create for new files.`);
      }
      try {
        const output = await runShow(absolutePath, args.start, args.end);
        return { content: [{ type: "text", text: output.text }], details: { path: args.path, start: args.start, end: args.end, truncated: output.truncated } };
      } catch (error) {
        throw await anchorlineError(error);
      }
    },
    renderResult(result, _options, theme) {
      const details = result.details as { path?: string; start?: number; end?: number; truncated?: boolean } | undefined;
      const range = details?.start ? `:${details.start}-${details.end ?? "end"}` : "";
      const suffix = details?.truncated ? " (trimmed; use range)" : "";
      return new Text(theme.fg("muted", `${String(details?.path ?? "")}${range}${suffix}`), 0, 0);
    },
  });

  pi.registerTool({
    name: "anchorline-edit",
    label: "Anchorline Edit",
    description: "Apply anchorline patch from latest anchorline-show. Pack same-file edits into one patch; rerun show after edit; never parallel same path.",
    promptSnippet: "Use anchorline-edit only after fresh anchorline-show. Pack same-file edits. No sed/python/perl rewrites.",
    parameters: Type.Object({
      path: Type.String({ description: "Existing file path. Must be inside cwd." }),
      patch: Type.String({ description: "Patch from latest anchorline-show output. Pack multiple same-file edits into this one patch." }),
    }),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = params as AnchorlineEditParams;
      const absolutePath = resolveEditPath(ctx.cwd, args.path);
      if (activeEditPaths.has(absolutePath)) {
        throw new Error("pack same-file edits into one patch from one show");
      }
      if (!(await pathExists(absolutePath))) {
        throw new Error(`File not found: ${args.path}. Use file-create for new files.`);
      }
      activeEditPaths.add(absolutePath);
      try {
        return await withFileMutationQueue(absolutePath, async () => {
          const before = await readFile(absolutePath, "utf8");
          try {
            await runAnchorline(["edit", absolutePath], args.patch);
          } catch (error) {
            throw await anchorlineError(error);
          }
          const after = await readFile(absolutePath, "utf8");
          const state = await runShow(absolutePath);
          const diff = await renderDeltaDiff(ctx.cwd, args.path, before, after);
          return { content: [{ type: "text", text: diff }], details: { path: args.path, state: state.text, stateTruncated: state.truncated } };
        });
      } finally {
        activeEditPaths.delete(absolutePath);
      }
    },

    renderResult(result, _options, _theme) {
      const details = result.details as { path?: string } | undefined;
      const text = result.content.find((item) => item.type === "text")?.text ?? `edited ${String(details?.path ?? "")}`;
      return new Text(text, 0, 0);
    },
  });
}
