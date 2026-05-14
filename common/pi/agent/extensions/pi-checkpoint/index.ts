import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import path from "node:path";

const CUSTOM_TYPE = "pi-checkpoint";
const PI_PREFIX = "[PI] checkpoint:";
const EXEC_TIMEOUT = 15_000;
const BLOCKED_PUSH_RE = /(^|[\s;&|()])git\s+push(\s|$)/;

const SECRET_PATH_RE = /(^|\/)(\.env(\..*)?|auth\.json|id_rsa|id_ed25519|.*\.pem|.*\.key)$/i;

type Snapshot = {
  cwd: string;
  root: string | null;
  gitDir: string | null;
  dirtyFiles: Set<string>;
  ok: boolean;
  reason?: string;
};

type CheckpointDetails = {
  status: "created" | "skipped" | "blocked" | "undone" | "failed";
  hash?: string;
  files?: string[];
  reason?: string;
};

function splitZ(value: string): string[] {
  return value.split("\0").filter((item) => item.length > 0);
}

function uniqueSorted(values: Iterable<string>): string[] {
  return Array.from(new Set(values)).sort((a, b) => a.localeCompare(b));
}

function isSensitivePath(filePath: string): boolean {
  return SECRET_PATH_RE.test(filePath);
}

function formatTreeItems(items: string[], indent = ""): string[] {
  return items.map((item, index) => `${indent}${index === items.length - 1 ? "└──" : "├──"} ${item}`);
}

function firstLine(value: string): string {
  return value.split("\n")[0]?.trim() ?? "";
}

function checkpointSubject(files: string[]): string {
  if (files.length === 1) return `${PI_PREFIX} update ${path.basename(files[0])}`;
  if (files.length <= 3) return `${PI_PREFIX} update ${files.map((file) => path.basename(file)).join(", ")}`;
  return `${PI_PREFIX} update ${files.length} files`;
}

function formatMessage(details: CheckpointDetails): string {
  if (details.status === "created") {
    const files = details.files ?? [];
    return [
      `created [PI] ${details.hash ?? "unknown"}`,
      "├── files",
      ...formatTreeItems(files, "│   "),
      "└── undo",
      "    └── /undo resets files to previous commit if HEAD is [PI]",
    ].join("\n");
  }

  if (details.status === "undone") {
    return [`undone ${details.hash ?? "unknown"}`, "└── files reset to previous commit"].join("\n");
  }

  return [`${details.status}`, `└── ${details.reason ?? "no details"}`].join("\n");
}

async function git(pi: ExtensionAPI, cwd: string, args: string[]): Promise<{ stdout: string; stderr: string; code: number }> {
  return pi.exec("git", args, { cwd, timeout: EXEC_TIMEOUT });
}

async function gitOk(pi: ExtensionAPI, cwd: string, args: string[]): Promise<boolean> {
  const result = await git(pi, cwd, args);
  return result.code === 0;
}

async function gitOutput(pi: ExtensionAPI, cwd: string, args: string[]): Promise<string | null> {
  const result = await git(pi, cwd, args);
  if (result.code !== 0) return null;
  return result.stdout.trim();
}

async function collectDirtyFiles(pi: ExtensionAPI, cwd: string): Promise<Set<string>> {
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

async function snapshot(pi: ExtensionAPI, cwd: string): Promise<Snapshot> {
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

async function sendCheckpointMessage(pi: ExtensionAPI, details: CheckpointDetails): Promise<void> {
  pi.sendMessage(
    {
      customType: CUSTOM_TYPE,
      content: formatMessage(details),
      display: true,
      details,
    },
    { deliverAs: "nextTurn" },
  );
}

async function createCheckpoint(pi: ExtensionAPI, ctx: ExtensionContext, before: Snapshot): Promise<void> {
  if (!before.ok || !before.root) return;

  const after = await snapshot(pi, ctx.cwd);
  if (!after.ok || !after.root) {
    await sendCheckpointMessage(pi, { status: "skipped", reason: after.reason ?? "git state unavailable" });
    return;
  }

  if (before.root !== after.root) {
    await sendCheckpointMessage(pi, { status: "skipped", reason: "git root changed during turn" });
    return;
  }

  const changedFiles = uniqueSorted(
    Array.from(after.dirtyFiles).filter((f) => !before.dirtyFiles.has(f)),
  );
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

  const add = await git(pi, after.root, ["add", "--", ...changedFiles]);
  if (add.code !== 0) {
    await sendCheckpointMessage(pi, { status: "failed", files: changedFiles, reason: firstLine(add.stderr) || "git add failed" });
    return;
  }

  const subject = checkpointSubject(changedFiles);
  const body = [
    "Local Pi checkpoint commit.",
    "Squash before push.",
    `Session: ${ctx.sessionManager.getSessionId()}`,
    "",
    "Files:",
    ...changedFiles.map((file) => `- ${file}`),
  ].join("\n");

  const commit = await git(pi, after.root, ["commit", "--no-verify", "-m", subject, "-m", body]);
  if (commit.code !== 0) {
    await sendCheckpointMessage(pi, {
      status: "failed",
      files: changedFiles,
      reason: firstLine(commit.stderr) || firstLine(commit.stdout) || "git commit failed",
    });
    return;
  }

  const hash = (await gitOutput(pi, after.root, ["rev-parse", "--short", "HEAD"])) ?? "unknown";
  await sendCheckpointMessage(pi, { status: "created", hash, files: changedFiles });
}

async function latestCommitSubject(pi: ExtensionAPI, cwd: string): Promise<string | null> {
  return gitOutput(pi, cwd, ["log", "-1", "--pretty=%s"]);
}

export default function piCheckpointExtension(pi: ExtensionAPI): void {
  let turnSnapshot: Snapshot | null = null;

  pi.registerMessageRenderer<CheckpointDetails>(CUSTOM_TYPE, (message, _options, theme) => {
    const content = typeof message.content === "string" ? message.content : "";
    return new Text(`${theme.fg("success", "checkpoint")}\n${theme.fg("muted", content)}`, 0, 0);
  });

  pi.on("tool_call", (event) => {
    if (event.toolName !== "bash") return;
    const command = typeof event.input.command === "string" ? event.input.command : "";
    if (!BLOCKED_PUSH_RE.test(command)) return;
    return { block: true, reason: "git push is blocked by pi-checkpoint; push manually outside Pi." };
  });

  pi.on("turn_start", async (_event, ctx) => {
    if (!ctx.hasUI) {
      turnSnapshot = null;
      return;
    }
    turnSnapshot = await snapshot(pi, ctx.cwd);
  });

  pi.on("turn_end", async (_event, ctx) => {
    if (!ctx.hasUI) {
      turnSnapshot = null;
      return;
    }
    const before = turnSnapshot;
    turnSnapshot = null;
    if (!before?.ok) return;
    await createCheckpoint(pi, ctx, before);
  });

  pi.registerCommand("undo", {
    description: "Undo latest [PI] checkpoint commit with git reset --hard HEAD~1",
    handler: async (_args, ctx) => {
      await ctx.waitForIdle();
      const current = await snapshot(pi, ctx.cwd);
      if (!current.ok || !current.root) {
        ctx.ui.notify(current.reason ?? "not inside git worktree", "warning");
        return;
      }

      const dirty = uniqueSorted(current.dirtyFiles);
      if (dirty.length > 0) {
        ctx.ui.notify("Refusing /undo with dirty worktree. Commit, stash, or clean changes first.", "warning");
        return;
      }

      const subject = await latestCommitSubject(pi, current.root);
      if (!subject?.startsWith(PI_PREFIX)) {
        ctx.ui.notify("HEAD is not a [PI] checkpoint commit; file undo skipped.", "warning");
        return;
      }

      const hash = (await gitOutput(pi, current.root, ["rev-parse", "--short", "HEAD"])) ?? "unknown";
      const reset = await git(pi, current.root, ["reset", "--hard", "HEAD~1"]);
      if (reset.code !== 0) {
        ctx.ui.notify(firstLine(reset.stderr) || "git reset failed", "error");
        return;
      }

      await sendCheckpointMessage(pi, { status: "undone", hash });
    },
  });
}
