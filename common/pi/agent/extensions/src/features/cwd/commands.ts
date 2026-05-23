import { SessionManager, type ExtensionAPI, type ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { stat } from "node:fs/promises";
import { homedir } from "node:os";
import { resolve } from "node:path";

type CwdSwitchMode = "full" | "summary";

type SessionMessageLike = {
  role?: string;
  content?: string | Array<{ type?: string; text?: string }>;
};

type SessionBranchEntryLike = {
  type: string;
  summary?: string;
  message?: SessionMessageLike;
};

function expandHome(path: string): string {
  if (path === "~") return homedir();
  if (path.startsWith("~/")) return resolve(homedir(), path.slice(2));
  return path;
}

function parseCwdArgs(args: string): { mode: CwdSwitchMode; input: string } {
  let input = args.trim();
  let mode: CwdSwitchMode = "full";

  while (true) {
    if (input.startsWith("--summary")) {
      mode = "summary";
      input = input.slice("--summary".length).trimStart();
      continue;
    }
    if (input.startsWith("--full")) {
      mode = "full";
      input = input.slice("--full".length).trimStart();
      continue;
    }
    return { mode, input };
  }
}

async function resolveTargetCwd(input: string, cwd: string): Promise<string> {
  const resolved = resolve(cwd, expandHome(input));
  const target = await stat(resolved).catch(() => null);
  if (!target) throw new Error(`Directory not found: ${resolved}`);
  if (!target.isDirectory()) throw new Error(`Not a directory: ${resolved}`);
  return resolved;
}

function extractMessageText(message: SessionMessageLike | undefined): string {
  const content = message?.content;
  if (typeof content === "string") return content.trim();
  if (!Array.isArray(content)) return "";

  const text = content
    .filter((block) => block?.type === "text" && typeof block.text === "string")
    .map((block) => block.text?.trim() ?? "")
    .filter(Boolean)
    .join("\n");

  return text.trim();
}

function buildSummaryHandoff(ctx: ExtensionCommandContext, targetCwd: string): string {
  const branch = ctx.sessionManager.getBranch() as SessionBranchEntryLike[];
  const sessionName = ctx.sessionManager.getSessionName();
  const summaries = branch
    .filter((entry) => (entry.type === "compaction" || entry.type === "branch_summary") && typeof entry.summary === "string")
    .map((entry) => entry.summary?.trim() ?? "")
    .filter(Boolean)
    .slice(-3);
  const transcript = branch
    .filter((entry) => entry.type === "message")
    .map((entry) => {
      const role = entry.message?.role;
      if (role !== "user" && role !== "assistant") return "";
      const text = extractMessageText(entry.message);
      if (!text) return "";
      return `${role === "user" ? "User" : "Assistant"}: ${text}`;
    })
    .filter(Boolean)
    .slice(-12);

  const lines = [
    `Session handoff from ${ctx.cwd} to ${targetCwd}.`,
    sessionName ? `Session name: ${sessionName}.` : "Session name: unnamed.",
    "Carry forward goals, constraints, and decisions from this handoff.",
    "Target cwd changed. Re-check files and assumptions against target repo before editing.",
  ];

  if (summaries.length > 0) {
    lines.push("", "Known summaries:", ...summaries.map((summary) => `- ${summary}`));
  }

  if (transcript.length > 0) {
    lines.push("", "Recent transcript:", ...transcript.map((line) => `- ${line}`));
  }

  return lines.join("\n");
}

async function switchWithFullHandoff(targetCwd: string, ctx: ExtensionCommandContext): Promise<void> {
  const sourceSessionPath = ctx.sessionManager.getSessionFile();
  if (!sourceSessionPath) throw new Error("Current session file not available");

  const nextSession = SessionManager.forkFrom(sourceSessionPath, targetCwd);
  const sessionPath = nextSession.getSessionFile();
  if (!sessionPath) throw new Error(`Could not create session for ${targetCwd}`);

  const result = await ctx.switchSession(sessionPath, {
    withSession: async (nextCtx) => {
      nextCtx.ui.notify(`cwd ${targetCwd} (full handoff)`, "info");
    },
  });

  if (result.cancelled) {
    ctx.ui.notify("/cwd cancelled", "warning");
  }
}

async function switchWithSummaryHandoff(targetCwd: string, ctx: ExtensionCommandContext): Promise<void> {
  const handoff = buildSummaryHandoff(ctx, targetCwd);
  const sourceCwd = ctx.cwd;
  const nextSession = SessionManager.continueRecent(targetCwd);
  const sessionPath = nextSession.getSessionFile();
  if (!sessionPath) throw new Error(`No session available for ${targetCwd}`);

  const result = await ctx.switchSession(sessionPath, {
    withSession: async (nextCtx) => {
      await nextCtx.sendMessage(
        {
          customType: "cwd-handoff",
          content: handoff,
          display: true,
          details: { mode: "summary", sourceCwd, targetCwd },
        },
        { triggerTurn: false },
      );
      nextCtx.ui.notify(`cwd ${targetCwd} (summary handoff)`, "info");
    },
  });

  if (result.cancelled) {
    ctx.ui.notify("/cwd cancelled", "warning");
  }
}

async function switchCwd(args: string, ctx: ExtensionCommandContext): Promise<void> {
  const parsed = parseCwdArgs(args);
  let input = parsed.input;
  if (!input && ctx.hasUI) {
    input = (await ctx.ui.input("Switch working directory", ctx.cwd))?.trim() ?? "";
  }
  if (!input) {
    ctx.ui.notify(`cwd ${ctx.cwd}`, "info");
    return;
  }

  try {
    const targetCwd = await resolveTargetCwd(input, ctx.cwd);
    if (targetCwd === ctx.cwd) {
      ctx.ui.notify(`cwd ${targetCwd}`, "info");
      return;
    }

    if (parsed.mode === "summary") {
      await switchWithSummaryHandoff(targetCwd, ctx);
      return;
    }

    await switchWithFullHandoff(targetCwd, ctx);
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown error";
    ctx.ui.notify(`cwd switch failed: ${message}`, "error");
  }
}

export function registerCwdCommands(pi: ExtensionAPI): void {
  pi.registerCommand("cwd", {
    description: "Move session to another working directory. Default: full handoff. Optional: --summary.",
    handler: async (args, ctx) => switchCwd(args, ctx),
  });
}