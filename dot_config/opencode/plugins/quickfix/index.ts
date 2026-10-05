import { execFile } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import {
  mkdir,
  readFile,
  realpath,
  rename,
  rm,
  stat,
  writeFile,
} from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";
import { promisify } from "node:util";
import { Plugin } from "@opencode/plugin";

const execFileAsync = promisify(execFile);
const MAX_LOCATIONS = 50;
const MAX_FILE_BYTES = 2 * 1024 * 1024;

const quickfixArgsSchema = {
  type: "object",
  properties: {
    locations: {
      type: "array",
      minItems: 1,
      maxItems: MAX_LOCATIONS,
      items: {
        type: "object",
        properties: {
          path: { type: "string", minLength: 1 },
          line: { type: "integer", minimum: 1 },
          column: { type: "integer", minimum: 1 },
          reason: { type: "string", minLength: 1 },
        },
        required: ["path", "line", "reason"],
        additionalProperties: false,
      },
    },
  },
  required: ["locations"],
  additionalProperties: false,
} as const;

export interface QuickfixLocationInput {
  path: string;
  line: number;
  column?: number;
  reason: string;
}

interface QuickfixArgs {
  locations: QuickfixLocationInput[];
}

export interface QuickfixEntry {
  filename: string;
  lnum: number;
  col: number;
  text: string;
}

export interface PreparedQuickfix {
  entries: QuickfixEntry[];
  worktree: string;
}

export interface QuickfixState {
  worktree: string;
  entries: QuickfixEntry[];
  updated_at: string;
}

function isInside(root: string, target: string): boolean {
  const relative = path.relative(root, target);
  return (
    relative === "" ||
    (!relative.startsWith(`..${path.sep}`) &&
      relative !== ".." &&
      !path.isAbsolute(relative))
  );
}

function countLines(source: string): number {
  const lines = source.split(/\r\n|\n|\r/);
  if (source.endsWith("\n") || source.endsWith("\r")) lines.pop();
  return lines.length;
}

async function worktreePath(directory: string): Promise<string> {
  const resolvedDirectory = await realpath(directory);
  try {
    const result = await execFileAsync("git", [
      "-C",
      resolvedDirectory,
      "rev-parse",
      "--show-toplevel",
    ]);
    return await realpath(result.stdout.trim());
  } catch {
    return resolvedDirectory;
  }
}

async function prepareLocation(
  root: string,
  directory: string,
  input: QuickfixLocationInput,
): Promise<QuickfixEntry> {
  const reason = input.reason.trim();
  if (!reason) {
    throw new Error(
      `Quickfix reason is required for ${input.path}:${input.line}.`,
    );
  }
  if (/\r|\n/.test(reason)) {
    throw new Error(
      `Quickfix reason must be one line: ${input.path}:${input.line}.`,
    );
  }

  const candidate = path.resolve(directory, input.path);
  const filename = await realpath(candidate);
  if (!isInside(root, filename)) {
    throw new Error(`Path must be inside the worktree: ${input.path}`);
  }

  const file = await stat(filename);
  if (!file.isFile()) throw new Error(`Not a file: ${input.path}`);
  if (file.size > MAX_FILE_BYTES) {
    throw new Error(`File is too large to inspect: ${input.path}`);
  }

  const totalLines = countLines(await readFile(filename, "utf8"));
  if (input.line > totalLines) {
    throw new Error(
      `Line ${input.line} exceeds file length ${totalLines}: ${input.path}`,
    );
  }

  return {
    filename,
    lnum: input.line,
    col: input.column ?? 1,
    text: reason,
  };
}

export async function prepareQuickfix(
  directory: string,
  inputs: QuickfixLocationInput[],
): Promise<PreparedQuickfix> {
  if (!inputs.length) {
    throw new Error("At least one quickfix location is required.");
  }
  if (inputs.length > MAX_LOCATIONS) {
    throw new Error(`Quickfix supports at most ${MAX_LOCATIONS} locations.`);
  }

  const root = await worktreePath(directory);
  const entries: QuickfixEntry[] = [];

  for (const input of inputs) {
    entries.push(await prepareLocation(root, directory, input));
  }

  return {
    entries,
    worktree: root,
  };
}

function statePath(worktree: string): string {
  const stateHome =
    process.env.XDG_STATE_HOME ?? path.join(homedir(), ".local", "state");
  const key = createHash("sha256").update(worktree).digest("hex");
  return path.join(stateHome, "opencode", "quickfix", `${key}.json`);
}

async function saveQuickfixState(
  worktree: string,
  entries: QuickfixEntry[],
): Promise<string> {
  const target = statePath(worktree);
  const temporary = `${target}.${process.pid}.${randomUUID()}.tmp`;
  const state: QuickfixState = {
    worktree,
    entries,
    updated_at: new Date().toISOString(),
  };

  await mkdir(path.dirname(target), { recursive: true });
  try {
    await writeFile(temporary, `${JSON.stringify(state)}\n`, {
      encoding: "utf8",
      mode: 0o600,
    });
    await rename(temporary, target);
  } finally {
    await rm(temporary, { force: true });
  }
  return target;
}

export default Plugin.define({
  id: "quickfix",
  async setup(ctx) {
    await ctx.tool.transform((editor) => {
      editor.add({
        name: "quickfix-model",
        description:
          "Validate source locations and store them as the latest model quickfix list for this worktree. Open it with the tmux quickfix binding.",
        input: quickfixArgsSchema,
        async execute(input, context) {
          const args = input as QuickfixArgs;
          const session = await ctx.session.get({
            sessionID: context.sessionID,
          });
          const prepared = await prepareQuickfix(
            session.location.directory,
            args.locations,
          );
          await saveQuickfixState(prepared.worktree, prepared.entries);

          const count = prepared.entries.length;
          let noun: string;
          if (count === 1) {
            noun = "location";
          } else {
            noun = "locations";
          }
          return {
            content: `Stored ${count} ${noun}. Open the model quickfix list with the tmux quickfix binding.`,
          };
        },
      });
    });
  },
});
