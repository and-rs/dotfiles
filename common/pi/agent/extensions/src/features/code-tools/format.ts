import path from "node:path";
import { MANIFESTS, MAX_OVERVIEW_FILES, type SearchMatch } from "./types.ts";

export function splitLines(value: string): string[] {
  return value.split("\n").map((line) => line.trimEnd()).filter((line) => line.length > 0);
}

export function clamp(value: number | undefined, min: number, max: number, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.max(min, Math.min(max, Math.trunc(value)));
}

export function displayPath(root: string, filePath: string): string {
  const relative = path.relative(root, filePath);
  return relative.length === 0 ? "." : relative;
}

export function topCounts(values: string[], limit: number): Array<[string, number]> {
  const counts = new Map<string, number>();
  for (const value of values) counts.set(value, (counts.get(value) ?? 0) + 1);
  return Array.from(counts.entries()).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).slice(0, limit);
}

export function formatTree(items: string[], indent = ""): string[] {
  return items.map((item, index) => `${indent}${index === items.length - 1 ? "└──" : "├──"} ${item}`);
}

export function languageKey(file: string): string {
  const ext = path.extname(file).replace(/^\./, "");
  if (ext) return ext;
  return path.basename(file);
}

export function topDir(file: string): string {
  const parts = file.split(/[\\/]/).filter(Boolean);
  return parts.length <= 1 ? "." : parts[0];
}

export function formatOverview(root: string, cwd: string, files: string[], status: string[], limit: number): string {
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

export function formatSearchMatches(matches: SearchMatch[]): string[] {
  if (matches.length === 0) return ["    └── none"];
  return formatTree(matches.map((match) => `${match.file}:${match.lineNumber}: ${match.text}`), "    ");
}

export function formatFilesList(
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
