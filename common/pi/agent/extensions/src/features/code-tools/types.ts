export const EXEC_TIMEOUT = 15_000;
export const MAX_SEARCH_RESULTS = 80;
export const MAX_OVERVIEW_FILES = 5000;
export const MAX_FILES_RESULTS = 500;

export const MANIFESTS = [
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

export type ExecOk = { stdout: string; stderr: string; code: number };

export type OverviewParams = {
  path?: string;
  limit?: number;
};

export type SearchParams = {
  query: string;
  path?: string;
  glob?: string;
  limit?: number;
  context?: number;
};

export type SearchMatch = {
  file: string;
  lineNumber: number;
  text: string;
};

export type FilesParams = {
  path?: string;
  glob?: string;
  type?: "file" | "dir";
  limit?: number;
};
