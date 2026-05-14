import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import path from "node:path";

const EXEC_TIMEOUT = 15_000;
const MAX_SEARCH_RESULTS = 80;
const MAX_OVERVIEW_FILES = 5000;
const MAX_FILES_RESULTS = 500;

const MANIFESTS = [
  "package.json",
  "pnpm-workspace.yaml",
  "bun.lockb",
  "bun.lock",
  "Cargo.toml",
  "pyproject.toml",
  "go.mod",
  "flake.nix",
  "deno.json",
  "tsconfig.json",
  "justfile",
  "Makefile",
];

type ExecOk = { stdout: string; stderr: string; code: number };

type OverviewParams = {
  path?: string;
  limit?: number;
};

type SearchParams = {
  query: string;
  path?: string;
  glob?: string;
  limit?: number;
  context?: number;
};
type SearchMatch = {
  file: string;
  lineNumber: number;
  text: string;
};


type FilesParams = {
  path?: string;
  glob?: string;
  type?: "file" | "dir";
  limit?: number;
};

function splitLines(value: string): string[] {
  return value.split("\n").map((line) => line.trimEnd()).filter((line) => line.length > 0);
}

function clamp(value: number | undefined, min: number, max: number, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.max(min, Math.min(max, Math.trunc(value)));
}

function displayPath(root: string, filePath: string): string {
  const relative = path.relative(root, filePath);
  return relative.length === 0 ? "." : relative;
}

function topCounts(values: string[], limit: number): Array<[string, number]> {
  const counts = new Map<string, number>();
  for (const value of values) counts.set(value, (counts.get(value) ?? 0) + 1);
  return Array.from(counts.entries()).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).slice(0, limit);
}

function formatTree(items: string[], indent = ""): string[] {
  return items.map((item, index) => `${indent}${index === items.length - 1 ? "└──" : "├──"} ${item}`);
}

async function exec(pi: ExtensionAPI, cwd: string, command: string, args: string[]): Promise<ExecOk> {
  return pi.exec(command, args, { cwd, timeout: EXEC_TIMEOUT });
}

async function output(pi: ExtensionAPI, cwd: string, command: string, args: string[]): Promise<string | null> {
  const result = await exec(pi, cwd, command, args);
  if (result.code !== 0) return null;
  return result.stdout.trim();
}

async function repoRoot(pi: ExtensionAPI, cwd: string): Promise<string> {
  return (await output(pi, cwd, "git", ["rev-parse", "--show-toplevel"])) ?? cwd;
}

async function gitFiles(pi: ExtensionAPI, root: string): Promise<string[]> {
  const tracked = await output(pi, root, "git", ["ls-files"]);
  if (tracked) return splitLines(tracked).slice(0, MAX_OVERVIEW_FILES);
  const rg = await output(pi, root, "rg", ["--files", "--hidden", "-g", "!.git"]);
  return rg ? splitLines(rg).slice(0, MAX_OVERVIEW_FILES) : [];
}

async function gitStatus(pi: ExtensionAPI, root: string): Promise<string[]> {
  const status = await output(pi, root, "git", ["status", "--short"]);
  return status ? splitLines(status).slice(0, 80) : [];
}

function languageKey(file: string): string {
  const ext = path.extname(file).replace(/^\./, "");
  if (ext) return ext;
  return path.basename(file);
}

function topDir(file: string): string {
  const parts = file.split(/[\\/]/).filter(Boolean);
  return parts.length <= 1 ? "." : parts[0];
}

function formatOverview(root: string, cwd: string, files: string[], status: string[], limit: number): string {
  const manifests = MANIFESTS.filter((name) => files.includes(name));
  const dirs = topCounts(files.map(topDir), 16).map(([name, count]) => `${String(count).padStart(4)}  ${name}`);
  const languages = topCounts(files.map(languageKey), 16).map(([name, count]) => `${String(count).padStart(4)}  ${name}`);
  const visibleStatus = status.slice(0, limit);
  return [
    "code-overview",
    `root: ${root}`,
    `cwd: ${displayPath(root, cwd)}`,
    `files: ${files.length}${files.length >= MAX_OVERVIEW_FILES ? "+" : ""}`,
    "├── manifests",
    ...(manifests.length > 0 ? formatTree(manifests, "│   ") : ["│   └── none"]),
    "├── top dirs",
    ...(dirs.length > 0 ? formatTree(dirs, "│   ") : ["│   └── none"]),
    "├── languages",
    ...(languages.length > 0 ? formatTree(languages, "│   ") : ["│   └── none"]),
    "└── git status",
    ...(visibleStatus.length > 0 ? formatTree(visibleStatus, "    ") : ["    └── clean"]),
  ].join("\n");
}

function parseRgJson(stdout: string, limit: number): SearchMatch[] {
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

function formatSearchMatches(matches: SearchMatch[]): string[] {
  if (matches.length === 0) return ["    └── none"];
  return formatTree(matches.map((match) => `${match.file}:${match.lineNumber}: ${match.text}`), "    ");
}


async function listFiles(
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

function formatFilesList(
  root: string,
  searchDir: string,
  files: string[],
  glob: string | undefined,
  type: string | undefined,
  truncated: boolean,
  via: string,
): string {
  return [
    "code-files",
    `path: ${displayPath(root, searchDir)}`,
    glob ? `glob: ${glob}` : undefined,
    type ? `type: ${type}` : undefined,
    `files: ${files.length}${truncated ? "+" : ""}`,
    `truncated: ${truncated}`,
    `via: ${via}`,
    "└── results",
    ...(files.length > 0 ? formatTree(files, "    ") : ["    └── none"]),
  ].filter((line): line is string => typeof line === "string").join("\n");
}
export default function codeToolsExtension(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "code-overview",
    label: "Code Overview",
    description: "Return compact git-aware codebase overview. Use before ls/find for unfamiliar repos.",
    promptSnippet: "Use code-overview for first-pass repo exploration instead of raw ls/find.",
    promptGuidelines: [
      "Use code-overview before broad ls/find commands in unfamiliar repos.",
      "Use code-search for content lookup; read exact files only when edits require anchors.",
    ],
    parameters: Type.Object({
      path: Type.Optional(Type.String({ description: "Directory to inspect. Defaults to cwd." })),
      limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 80, description: "Max git status rows. Default 40." })),
    }),
    execute: async (_toolCallId, params: OverviewParams) => {
      const cwd = params.path ? path.resolve(params.path) : process.cwd();
      const root = await repoRoot(pi, cwd);
      const files = await gitFiles(pi, root);
      const status = await gitStatus(pi, root);
      const text = formatOverview(root, cwd, files, status, clamp(params.limit, 1, 80, 40));
      return { content: [{ type: "text", text }], details: { root, cwd, files: files.length, status: status.length } };
    },
    renderCall(args, theme) {
      return new Text(`${theme.fg("toolTitle", theme.bold("code-overview"))} ${theme.fg("accent", args.path ?? ".")}`, 0, 0);
    },
    renderResult(result, { expanded }, theme) {
      const text = result.content.find((item) => item.type === "text")?.text ?? "";
      if (!expanded) return new Text(theme.fg("success", text.split("\n").slice(1, 4).join(" · ")), 0, 0);
      return new Text(`\n${theme.fg("toolOutput", text)}`, 0, 0);
    },
  });

  pi.registerTool({
    name: "code-search",
    label: "Code Search",
    description: "Ripgrep-backed code search with capped ranked snippets. Use instead of broad grep.",
    promptSnippet: "Use code-search for repository content lookup instead of broad grep.",
    promptGuidelines: [
      "Prefer code-search over raw grep for repo exploration.",
      "Keep query specific. Increase limit only when needed.",
    ],
    parameters: Type.Object({
      query: Type.String({ description: "Search query passed to ripgrep." }),
      path: Type.Optional(Type.String({ description: "Directory or file to search. Defaults to cwd." })),
      glob: Type.Optional(Type.String({ description: "Optional glob filter, e.g. **/*.ts." })),
      limit: Type.Optional(Type.Integer({ minimum: 1, maximum: MAX_SEARCH_RESULTS, description: "Max matches. Default 30." })),
      context: Type.Optional(Type.Integer({ minimum: 0, maximum: 3, description: "Context lines around matches. Default 0." })),
    }),
    execute: async (_toolCallId, params: SearchParams) => {
      const cwd = params.path ? path.resolve(params.path) : process.cwd();
      const root = await repoRoot(pi, cwd);
      const limit = clamp(params.limit, 1, MAX_SEARCH_RESULTS, 30);
      const context = clamp(params.context, 0, 3, 0);
      const args = ["--json", "--line-number", "--no-heading", "--color", "never", "--context", String(context)];
      if (params.glob) args.push("--glob", params.glob);
      args.push(params.query, cwd);
      const result = await exec(pi, root, "rg", args);
      if (result.code > 1) throw new Error(result.stderr || "rg failed");
      const matches = parseRgJson(result.stdout, limit);
      const files = new Set(matches.map((match) => match.file));
      const truncated = matches.length >= limit;
      const text = [
        "code-search",
        `query: ${params.query}`,
        `path: ${displayPath(root, cwd)}`,
        params.glob ? `glob: ${params.glob}` : undefined,
        `matches: ${matches.length}${truncated ? "+" : ""}`,
        `files: ${files.size}`,
        `truncated: ${truncated}`,
        "└── results",
        ...formatSearchMatches(matches),
      ].filter((line): line is string => typeof line === "string").join("\n");
      return { content: [{ type: "text", text }], details: { root, cwd, query: params.query, returned: matches.length, files: files.size, limit, truncated } };
    },
    renderCall(args, theme) {
      return new Text(`${theme.fg("toolTitle", theme.bold("code-search"))} ${theme.fg("accent", JSON.stringify(args.query ?? ""))}`, 0, 0);
    },
    renderResult(result, { expanded }, theme) {
      const text = result.content.find((item) => item.type === "text")?.text ?? "";
      if (!expanded) return new Text(theme.fg("success", text.split("\n").slice(1, 5).join(" · ")), 0, 0);
      return new Text(`\n${theme.fg("toolOutput", text)}`, 0, 0);
    },
  });

  pi.registerTool({
    name: "code-files",
    label: "Code Files",
    description: "List file paths by glob or type. fd-backed with rg/git fallbacks. Use instead of ls/find.",
    promptSnippet: "Use code-files for file path listing instead of bash ls or find.",
    promptGuidelines: [
      "Use code-files for file path discovery. Never use bash ls or find.",
      "Use code-overview for first repo orientation; code-files for specific path enumeration.",
    ],
    parameters: Type.Object({
      path: Type.Optional(Type.String({ description: "Directory to search. Defaults to cwd." })),
      glob: Type.Optional(Type.String({ description: "Glob filter, e.g. **/*.ts or *.nu." })),
      type: Type.Optional(Type.String({ description: "Filter by 'file' or 'dir'. Omit for both." })),
      limit: Type.Optional(Type.Integer({ minimum: 1, maximum: MAX_FILES_RESULTS, description: "Max results. Default 100." })),
    }),
    execute: async (_toolCallId, params: FilesParams) => {
      const searchDir = params.path ? path.resolve(params.path) : process.cwd();
      const root = await repoRoot(pi, searchDir);
      const limit = clamp(params.limit, 1, MAX_FILES_RESULTS, 100);
      const typeFilter = params.type === "file" || params.type === "dir" ? params.type : undefined;
      const { files, truncated, via } = await listFiles(pi, searchDir, params.glob, typeFilter, limit);
      const text = formatFilesList(root, searchDir, files, params.glob, typeFilter, truncated, via);
      return {
        content: [{ type: "text", text }],
        details: { root, searchDir, returned: files.length, truncated, via },
      };
    },
    renderCall(args, theme) {
      const parts = [args.path ?? ".", args.glob, args.type].filter(Boolean).join(" · ");
      return new Text(`${theme.fg("toolTitle", theme.bold("code-files"))} ${theme.fg("accent", parts)}`, 0, 0);
    },
    renderResult(result, { expanded }, theme) {
      const text = result.content.find((item) => item.type === "text")?.text ?? "";
      if (!expanded) return new Text(theme.fg("success", text.split("\n").slice(1, 5).join(" · ")), 0, 0);
      return new Text(`\n${theme.fg("toolOutput", text)}`, 0, 0);
    },
  });
}
