import { realpath, readFile, stat } from "node:fs/promises";
import path from "node:path";
import { tool, type Plugin, type ToolContext } from "@opencode-ai/plugin";
import { z } from "zod";

const MAX_LOCATIONS = 50;
const MAX_FILE_BYTES = 2 * 1024 * 1024;

const quickfixLocationSchema = z.object({
  path: z.string().min(1),
  line: z.number().int().min(1),
  column: z.number().int().min(1).optional(),
  reason: z.string().min(1),
});

const quickfixArgsSchema = {
  locations: z.array(quickfixLocationSchema).min(1).max(MAX_LOCATIONS),
};

export type QuickfixLocationInput = z.infer<typeof quickfixLocationSchema>;

export interface QuickfixEntry {
  filename: string;
  lnum: number;
  col: number;
  text: string;
}

export interface PreparedQuickfix {
  entries: QuickfixEntry[];
  paths: string[];
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

async function prepareLocation(
  root: string,
  directory: string,
  input: QuickfixLocationInput,
): Promise<QuickfixEntry> {
  const reason = input.reason.trim();
  if (!reason) {
    throw new Error(`Quickfix reason is required for ${input.path}:${input.line}.`);
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
  context: Pick<ToolContext, "directory" | "worktree">,
  inputs: QuickfixLocationInput[],
): Promise<PreparedQuickfix> {
  if (!inputs.length) {
    throw new Error("At least one quickfix location is required.");
  }
  if (inputs.length > MAX_LOCATIONS) {
    throw new Error(`Quickfix supports at most ${MAX_LOCATIONS} locations.`);
  }

  const root = await realpath(context.worktree);
  const entries: QuickfixEntry[] = [];

  for (const input of inputs) {
    entries.push(await prepareLocation(root, context.directory, input));
  }

  return {
    entries,
    paths: entries.map((entry) => path.relative(root, entry.filename)),
  };
}

function vimString(value: string): string {
  return `'${value.replaceAll("'", "''")}'`;
}

export function buildSetQuickfixExpression(entries: QuickfixEntry[]): string {
  const json = vimString(JSON.stringify(entries));
  return `setqflist(json_decode(${json}), 'r')`;
}

export function buildOpenQuickfixExpression(): string {
  return "execute('cfirst | copen | wincmd p')";
}

export function buildNvimArgs(server: string, expression: string): string[] {
  return ["--server", server, "--remote-expr", expression];
}

async function runRemoteExpression(
  server: string,
  expression: string,
): Promise<void> {
  let child: Bun.Subprocess;
  try {
    child = Bun.spawn(["nvim", ...buildNvimArgs(server, expression)], {
      stdout: "pipe",
      stderr: "pipe",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown error";
    throw new Error(`Could not start the nvim client: ${message}`);
  }

  const [exitCode, _stdout, stderr] = await Promise.all([
    child.exited,
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
  ]);
  if (exitCode !== 0) {
    throw new Error(stderr.trim() || `nvim remote expression failed (${exitCode})`);
  }
}

async function openQuickfix(
  server: string,
  entries: QuickfixEntry[],
): Promise<void> {
  await runRemoteExpression(server, buildSetQuickfixExpression(entries));
  await runRemoteExpression(server, buildOpenQuickfixExpression());
}

export default (async () => ({
  tool: {
    "quickfix-open": tool({
      description:
        "Validate source locations and open them in the active Neovim server's quickfix list. Requires NVIM.",
      args: quickfixArgsSchema,
      execute: async (args, context) => {
        const server = process.env.NVIM?.trim();
        if (!server) {
          throw new Error(
            "No active Neovim server found. Start OpenCode from a terminal inside Neovim so NVIM is available.",
          );
        }

        const prepared = await prepareQuickfix(context, args.locations);
        await openQuickfix(server, prepared.entries);

        return {
          title: "Quickfix opened",
          output: `Opened ${prepared.entries.length} location${prepared.entries.length === 1 ? "" : "s"} in Neovim quickfix.`,
          metadata: {
            server,
            paths: prepared.paths,
          },
        };
      },
    }),
  },
})) satisfies Plugin;
