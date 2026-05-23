import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { EXEC_TIMEOUT, MAX_OVERVIEW_FILES, type ExecOk, type SearchMatch } from "./types.ts";
import { splitLines } from "./format.ts";

export async function exec(pi: ExtensionAPI, cwd: string, command: string, args: string[]): Promise<ExecOk> {
  return pi.exec(command, args, { cwd, timeout: EXEC_TIMEOUT });
}

export async function output(pi: ExtensionAPI, cwd: string, command: string, args: string[]): Promise<string | null> {
  const result = await exec(pi, cwd, command, args);
  if (result.code !== 0) return null;
  return result.stdout.trim();
}

export async function repoRoot(pi: ExtensionAPI, cwd: string): Promise<string> {
  return (await output(pi, cwd, "git", ["rev-parse", "--show-toplevel"])) ?? cwd;
}

export async function gitFiles(pi: ExtensionAPI, root: string): Promise<string[]> {
  const tracked = await output(pi, root, "git", ["ls-files"]);
  if (tracked) return splitLines(tracked).slice(0, MAX_OVERVIEW_FILES);
  const rg = await output(pi, root, "rg", ["--files", "--hidden", "-g", "!.git"]);
  return rg ? splitLines(rg).slice(0, MAX_OVERVIEW_FILES) : [];
}

export async function gitStatus(pi: ExtensionAPI, root: string): Promise<string[]> {
  const status = await output(pi, root, "git", ["status", "--short"]);
  return status ? splitLines(status).slice(0, 80) : [];
}

export function parseRgJson(stdout: string, limit: number): SearchMatch[] {
  const rows: SearchMatch[] = [];
  for (const line of splitLines(stdout)) {
    if (rows.length >= limit) break;
    try {
      const event = JSON.parse(line) as {
        type?: string;
        data?: {
          path?: { text?: string };
          lines?: { text?: string };
          line_number?: number;
        };
      };
      if (event.type !== "match") continue;
      const file = event.data?.path?.text;
      const lineNumber = event.data?.line_number;
      const text = event.data?.lines?.text?.trimEnd();
      if (!file || !lineNumber || text === undefined) continue;
      rows.push({ file, lineNumber, text });
    } catch {
      continue;
    }
  }
  return rows;
}

export async function listFiles(
  pi: ExtensionAPI,
  searchDir: string,
  glob: string | undefined,
  type: "file" | "dir" | undefined,
  limit: number,
): Promise<{ files: string[]; truncated: boolean; via: string }> {
  const fdArgs: string[] = ["--color", "never", "--strip-cwd-prefix"];
  if (type === "file") fdArgs.push("--type", "f");
  else if (type === "dir") fdArgs.push("--type", "d");
  if (glob) fdArgs.push("--glob", glob);
  const fdResult = await exec(pi, searchDir, "fd", fdArgs);
  if (fdResult.code === 0) {
    const files = splitLines(fdResult.stdout);
    const truncated = files.length > limit;
    return { files: files.slice(0, limit), truncated, via: "fd" };
  }

  if (type !== "dir") {
    const rgArgs: string[] = ["--files", "--color", "never", "--hidden", "-g", "!.git"];
    if (glob) rgArgs.push("--glob", glob);
    rgArgs.push(".");
    const rgResult = await exec(pi, searchDir, "rg", rgArgs);
    if (rgResult.code === 0) {
      const files = splitLines(rgResult.stdout).map((f) => f.replace(/^\.\//, ""));
      const truncated = files.length > limit;
      return { files: files.slice(0, limit), truncated, via: "rg" };
    }
  }

  if (type !== "dir") {
    const gitArgs: string[] = ["ls-files"];
    if (glob && !glob.startsWith("**/")) gitArgs.push(glob);
    const gitResult = await exec(pi, searchDir, "git", gitArgs);
    if (gitResult.code === 0) {
      const files = splitLines(gitResult.stdout);
      const truncated = files.length > limit;
      return { files: files.slice(0, limit), truncated, via: "git ls-files" };
    }
  }

  return { files: [], truncated: false, via: "none" };
}
