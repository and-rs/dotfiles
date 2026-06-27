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
};

type AnchorlineEditParams = {
  path: string;
  patch: string;
};

const ANCHORLINE_BIN = resolve(homedir(), ".cargo/bin/anchorline");

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

async function runShow(path: string): Promise<string> {
  return runAnchorline(["show", path]);
}

export default function registerAnchorlineFeature(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "anchorline-show",
    label: "Anchorline Show",
    description: "Show anchored lines for existing file. Use before edit to refresh context.",
    promptSnippet: "Use anchorline-show before anchorline-edit to refresh line anchors.",
    parameters: Type.Object({
      path: Type.String({ description: "Existing file path. Must be inside cwd." }),
    }),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = params as AnchorlineShowParams;
      const absolutePath = resolveEditPath(ctx.cwd, args.path);
      if (!(await pathExists(absolutePath))) {
        throw new Error(`File not found: ${args.path}. Use file-create for new files.`);
      }
      const output = await runShow(absolutePath);
      return { content: [{ type: "text", text: output }], details: { path: args.path } };
    },
    renderResult(result, _options, theme) {
      const details = result.details as { path?: string } | undefined;
      const path = String(details?.path ?? "");
      return new Text(theme.fg("muted", path), 0, 0);
    },
  });

  pi.registerTool({
    name: "anchorline-edit",
    label: "Anchorline Edit",
    description: "Apply anchorline patch to existing file. Patch should use current anchorline-show output.",
    promptSnippet: "Use anchorline-edit for existing files after anchorline-show. No sed. No inline python.",
    parameters: Type.Object({
      path: Type.String({ description: "Existing file path. Must be inside cwd." }),
      patch: Type.String({ description: "Anchorline patch text from current show output." }),
    }),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = params as AnchorlineEditParams;
      const absolutePath = resolveEditPath(ctx.cwd, args.path);
      if (!(await pathExists(absolutePath))) {
        throw new Error(`File not found: ${args.path}. Use file-create for new files.`);
      }
      return withFileMutationQueue(absolutePath, async () => {
        const before = await readFile(absolutePath, "utf8");
        await runAnchorline(["edit", absolutePath], args.patch);
        const after = await readFile(absolutePath, "utf8");
        const state = await runShow(absolutePath);
        const diff = await renderDeltaDiff(ctx.cwd, args.path, before, after);
        return { content: [{ type: "text", text: diff }], details: { path: args.path, state } };
      });
    },


    renderResult(result, _options, _theme) {
      const details = result.details as { path?: string } | undefined;
      const text = result.content.find((item) => item.type === "text")?.text ?? `edited ${String(details?.path ?? "")}`;
      return new Text(text, 0, 0);
    },
  });
}
