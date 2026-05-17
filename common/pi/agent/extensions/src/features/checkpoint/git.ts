import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import path from "node:path";
import type { BatchState, CheckpointDetails, Snapshot } from "./types.ts";

const PI_PREFIX = "[PI] checkpoint:";
const EXEC_TIMEOUT = 15_000;
const MAX_PENDING_TURNS = 3;
const MAX_PENDING_FILES = 6;
const SECRET_PATH_RE = /(^|\/)(\.env(\..*)?|auth\.json|id_rsa|id_ed25519|.*\.pem|.*\.key)$/i;

export async function git(pi: ExtensionAPI, cwd: string, args: string[]): Promise<{ stdout: string; stderr: string; code: number }> {
  return pi.exec("git", args, { cwd, timeout: EXEC_TIMEOUT });
}

export async function gitOk(pi: ExtensionAPI, cwd: string, args: string[]): Promise<boolean> {
  const result = await git(pi, cwd, args);
  return result.code === 0;
}

export async function gitOutput(pi: ExtensionAPI, cwd: string, args: string[]): Promise<string | null> {
  const result = await git(pi, cwd, args);
  if (result.code !== 0) return null;
  return result.stdout.trim();
}

function splitZ(value: string): string[] {
  return value.split("\0").filter((item) => item.length > 0);
}

export function uniqueSorted(values: Iterable<string>): string[] {
  return Array.from(new Set(values)).sort((a, b) => a.localeCompare(b));
}

export function isSensitivePath(filePath: string): boolean {
  return SECRET_PATH_RE.test(filePath);
}

export function firstLine(value: string): string {
  return value.split("\n")[0]?.trim() ?? "";
}

export function checkpointSubject(files: string[]): string {
  if (files.length === 1) return `${PI_PREFIX} update ${path.basename(files[0])}`;
  if (files.length <= 3) return `${PI_PREFIX} update ${files.map((file) => path.basename(file)).join(", ")}`;
  return `${PI_PREFIX} update ${files.length} files`;
}

export async function collectDirtyFiles(pi: ExtensionAPI, cwd: string): Promise<Set<string>> {
  const files = new Set<string>();
  const commands = [
    ["diff", "--name-only", "-z"],
    ["diff", "--cached", "--name-only", "-z"],
    ["ls-files", "--others", "--exclude-standard", "-z"],
  ];

  for (const args of commands) {
    const result = await git(pi, cwd, args);
    if (result.code !== 0) continue;
    for (const file of splitZ(result.stdout)) files.add(file);
  }

  return files;
}

async function hasGitStateFile(pi: ExtensionAPI, cwd: string, gitDir: string, name: string): Promise<boolean> {
  const result = await git(pi, cwd, ["rev-parse", "--verify", "-q", name]);
  if (result.code === 0) return true;
  const filePath = path.isAbsolute(gitDir) ? path.join(gitDir, name) : path.join(cwd, gitDir, name);
  const testResult = await pi.exec("test", ["-e", filePath], { cwd, timeout: EXEC_TIMEOUT });
  return testResult.code === 0;
}

async function weirdGitState(pi: ExtensionAPI, cwd: string, gitDir: string): Promise<string | null> {
  const branch = await gitOutput(pi, cwd, ["rev-parse", "--abbrev-ref", "HEAD"]);
  if (branch === "HEAD") return "detached HEAD";

  const states: Array<[string, string]> = [
    ["MERGE_HEAD", "merge in progress"],
    ["CHERRY_PICK_HEAD", "cherry-pick in progress"],
    ["REVERT_HEAD", "revert in progress"],
    ["BISECT_LOG", "bisect in progress"],
    ["rebase-merge", "rebase in progress"],
    ["rebase-apply", "rebase in progress"],
  ];

  for (const [name, reason] of states) {
    if (await hasGitStateFile(pi, cwd, gitDir, name)) return reason;
  }

  return null;
}

export async function snapshot(pi: ExtensionAPI, cwd: string): Promise<Snapshot> {
  if (!(await gitOk(pi, cwd, ["rev-parse", "--is-inside-work-tree"]))) {
    return { cwd, root: null, gitDir: null, dirtyFiles: new Set(), ok: false, reason: "not inside git worktree" };
  }

  const root = await gitOutput(pi, cwd, ["rev-parse", "--show-toplevel"]);
  const gitDir = await gitOutput(pi, cwd, ["rev-parse", "--git-dir"]);
  if (!root || !gitDir) {
    return { cwd, root, gitDir, dirtyFiles: new Set(), ok: false, reason: "could not resolve git root" };
  }

  const weird = await weirdGitState(pi, cwd, gitDir);
  if (weird) return { cwd, root, gitDir, dirtyFiles: new Set(), ok: false, reason: weird };

  return { cwd, root, gitDir, dirtyFiles: await collectDirtyFiles(pi, root), ok: true };
}

export function changedFilesSince(before: Snapshot, after: Snapshot): string[] {
  return uniqueSorted(Array.from(after.dirtyFiles).filter((file) => !before.dirtyFiles.has(file)));
}

export function checkpointThresholdReached(batch: BatchState): boolean {
  return batch.turns >= MAX_PENDING_TURNS || batch.files.size >= MAX_PENDING_FILES;
}

export async function flushCheckpoint(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  batch: BatchState,
  sendCheckpointMessage: (pi: ExtensionAPI, details: CheckpointDetails) => Promise<void>,
): Promise<void> {
  const current = await snapshot(pi, ctx.cwd);
  if (!current.ok || !current.root) {
    await sendCheckpointMessage(pi, { status: "skipped", reason: current.reason ?? "git state unavailable" });
    return;
  }

  if (current.root !== batch.root) {
    await sendCheckpointMessage(pi, { status: "skipped", reason: "git root changed during checkpoint batch" });
    return;
  }

  const changedFiles = uniqueSorted(Array.from(batch.files).filter((file) => current.dirtyFiles.has(file)));
  if (changedFiles.length === 0) return;

  const sensitiveFiles = changedFiles.filter(isSensitivePath);
  if (sensitiveFiles.length > 0) {
    await sendCheckpointMessage(pi, {
      status: "skipped",
      files: changedFiles,
      reason: `sensitive path detected: ${sensitiveFiles.join(", ")}`,
    });
    return;
  }

  const add = await git(pi, current.root, ["add", "--", ...changedFiles]);
  if (add.code !== 0) {
    await sendCheckpointMessage(pi, { status: "failed", files: changedFiles, reason: firstLine(add.stderr) || "git add failed" });
    return;
  }

  const subject = checkpointSubject(changedFiles);
  const body = [
    "Local Pi checkpoint commit.",
    "Squash before push.",
    `Session: ${ctx.sessionManager.getSessionId()}`,
    `File-changing turns batched: ${batch.turns}`,
    "",
    "Files:",
    ...changedFiles.map((file) => `- ${file}`),
  ].join("\n");

  const commit = await git(pi, current.root, ["commit", "--no-verify", "-m", subject, "-m", body]);
  if (commit.code !== 0) {
    await sendCheckpointMessage(pi, {
      status: "failed",
      files: changedFiles,
      reason: firstLine(commit.stderr) || firstLine(commit.stdout) || "git commit failed",
    });
    return;
  }

  const hash = (await gitOutput(pi, current.root, ["rev-parse", "--short", "HEAD"])) ?? "unknown";
  await sendCheckpointMessage(pi, { status: "created", hash, files: changedFiles });
}
