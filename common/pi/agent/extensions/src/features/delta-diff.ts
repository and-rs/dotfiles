import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";

type CommandResult = { stdout: string; stderr: string; code: number };

function runCommand(command: string, args: string[], options: { cwd?: string; input?: string } = {}): Promise<CommandResult> {
  return new Promise((resolveResult) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      stdio: [options.input === undefined ? "ignore" : "pipe", "pipe", "pipe"],
    });
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
    child.once("error", (error) => resolveResult({ stdout: "", stderr: String(error), code: 1 }));
    child.once("close", (code) => resolveResult({ stdout, stderr, code: code ?? 1 }));
    if (options.input !== undefined) child.stdin.end(options.input, "utf8");
  });
}

async function hasDelta(): Promise<boolean> {
  const result = await runCommand("sh", ["-lc", "command -v delta >/dev/null 2>&1"]);
  return result.code === 0;
}

async function colorizeDiff(diff: string): Promise<string> {
  if (!(await hasDelta())) return diff;
  const result = await runCommand("delta", ["--paging=never"], { input: diff });
  return result.code === 0 && result.stdout.length > 0 ? result.stdout : diff;
}

function rewriteNoIndexHeader(diff: string, path: string, created: boolean): string {
  return diff
    .replace(/^diff --git a\/.* b\/.*$/m, `diff --git a/${path} b/${path}`)
    .replace(/^--- .*$/m, created ? "--- /dev/null" : `--- a/${path}`)
    .replace(/^\+\+\+ .*$/m, `+++ b/${path}`);
}

export async function renderDeltaDiff(cwd: string, path: string, before: string, after: string): Promise<string> {
  if (before === after) return before.length === 0 ? `Created empty file: ${path}` : "No changes.";
  const dir = await mkdtemp(join(tmpdir(), "pi-delta-"));
  try {
    const beforePath = join(dir, "before");
    const afterPath = join(dir, "after");
    await writeFile(beforePath, before, "utf8");
    await writeFile(afterPath, after, "utf8");
    const result = await runCommand("git", ["diff", "--no-index", "--", beforePath, afterPath], { cwd });
    if (result.code > 1 || result.stdout.trim().length === 0) return "No changes.";
    return colorizeDiff(rewriteNoIndexHeader(result.stdout, path, before.length === 0));
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}
