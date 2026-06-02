import { mkdtemp, rm, stat } from "node:fs/promises";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";
import { mkdir, writeFile } from "node:fs/promises";
import { spawn } from "node:child_process";
import { Text } from "@earendil-works/pi-tui";

export async function pathExists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

function runCommand(command: string, args: string[], options: { cwd?: string; input?: string } = {}): Promise<{ stdout: string; stderr: string; code: number }> {
  return new Promise((resolve) => {
    const child = spawn(command, args, { cwd: options.cwd, stdio: [options.input ? 'pipe' : 'ignore', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => { stdout += String(chunk); });
    child.stderr.on('data', (chunk) => { stderr += String(chunk); });
    child.on('close', (code) => resolve({ stdout, stderr, code: code ?? 1 }));
    if (options.input) child.stdin.end(options.input);
  });
}

async function hasDelta(): Promise<boolean> {
  const result = await runCommand('sh', ['-lc', 'command -v delta >/dev/null 2>&1']);
  return result.code === 0;
}

async function colorizeDiff(diff: string): Promise<string> {
  if (!(await hasDelta())) return diff;
  const result = await runCommand('delta', ['--paging=never'], { input: diff });
  return result.code === 0 ? result.stdout : diff;
}

async function gitDiff(cwd: string, paths: string[]): Promise<string> {
  const result = await runCommand('git', ['diff', '--no-ext-diff', '--', ...paths], { cwd });
  return result.code <= 1 ? result.stdout : '';
}

function rewriteNoIndexHeader(diff: string, path: string, beforePath: string, afterPath: string): string {
  return diff.replace(/^diff --git a\/.* b\/.*$/m, `diff --git a/${path} b/${path}`).replace(/^--- .*$/m, `--- ${beforePath}`).replace(/^\+\+\+ .*$/m, `+++ ${afterPath}`);
}

async function noIndexDiff(cwd: string, file: { path: string; before: string; after: string }): Promise<string> {
  const dir = await mkdtemp(join(tmpdir(), 'pi-hashline-'));
  const beforePath = `${dir}/before`;
  const afterPath = `${dir}/after`;
  await mkdir(dirname(beforePath), { recursive: true });
  await writeFile(beforePath, file.before, 'utf8');
  await writeFile(afterPath, file.after, 'utf8');
  const result = await runCommand('git', ['diff', '--no-index', '--', beforePath, afterPath], { cwd });
  await rm(dir, { recursive: true, force: true });
  if (result.code > 1) return '';
  return rewriteNoIndexHeader(result.stdout, file.path, `a/${file.path}`, `b/${file.path}`);
}

export async function buildEditDiff(cwd: string, files: Array<{ path: string; before: string; after: string; changed: boolean }>): Promise<string> {
  const changed = files.filter((file) => file.changed);
  if (changed.length === 0) return 'No changes.';
  const paths = changed.map((file) => file.path);
  const gitBased = await gitDiff(cwd, paths);
  if (gitBased.trim().length > 0) return colorizeDiff(gitBased);
  const chunks = await Promise.all(changed.map((file) => noIndexDiff(cwd, file)));
  return colorizeDiff(chunks.filter((chunk) => chunk.trim().length > 0).join("\n"));
}

export function renderDiffResult(result: { details?: { diff?: string }; content: Array<{ type: string; text?: string }> }, theme: { fg: (name: string, text: string) => string }, empty: string): Text {
  const diff = result.details?.diff ?? result.content.find((content) => content.type === 'text')?.text ?? '';
  return new Text(diff || theme.fg('dim', empty), 0, 0);
}