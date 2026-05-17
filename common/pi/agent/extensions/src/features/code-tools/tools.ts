import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import path from "node:path";
import { renderToolCall, renderToolResult } from "./renderers.ts";
import { clamp, displayPath, formatFilesList, formatOverview, formatSearchMatches } from "./format.ts";
import { exec, gitFiles, gitStatus, listFiles, parseRgJson, repoRoot } from "./git.ts";
import { MAX_FILES_RESULTS, MAX_SEARCH_RESULTS, type FilesParams, type OverviewParams, type SearchParams } from "./types.ts";

export function registerCodeTools(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "code-overview",
    label: "Code Overview",
    description: "Return compact git-aware codebase overview. Use before ls/find for unfamiliar repos.",
    promptSnippet: "Use code-overview for first-pass repo exploration instead of raw ls/find.",
    parameters: Type.Object({
      path: Type.Optional(Type.String({ description: "Directory to inspect. Defaults to cwd." })),
      limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 80, description: "Max git status rows. Default 40." })),
    }),
    execute: async (_toolCallId, params: OverviewParams) => {
      const cwd = params.path ? path.resolve(params.path) : process.cwd();
      const root = await repoRoot(pi, cwd);
      const files = await gitFiles(pi, root);
      const status = await gitStatus(pi, root);
      const limit = clamp(params.limit, 1, 80, 40);
      const text = formatOverview(root, cwd, files, status, limit);
      return { content: [{ type: "text", text }], details: { root, cwd, files: files.length, status: status.length } };
    },
    renderCall(args, theme) { return renderToolCall("code-overview", args.path ?? ".", theme); },
    renderResult(result, { expanded }, theme) { return renderToolResult(result.content.find((item) => item.type === "text")?.text ?? "", 3, expanded, theme); },
  });

  pi.registerTool({
    name: "code-search",
    label: "Code Search",
    description: "Ripgrep-backed code search with capped ranked snippets. Use instead of broad grep.",
    promptSnippet: "Use code-search for repository content lookup instead of broad grep.",
    promptGuidelines: ["Prefer code-search over raw grep for repo exploration.", "Keep query specific. Increase limit only when needed."],
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
      const args = ["--json", "--line-number", "--no-heading", "--color", "never", "--context", String(context), "--glob", "!**/*.map", "--glob", "!**/node_modules/**", "--glob", "!**/.git/**"];
      if (params.glob) args.push("--glob", params.glob);
      args.push(params.query, cwd);
      const result = await exec(pi, root, "rg", args);
      if (result.code > 1) throw new Error(result.stderr || "rg failed");
      const matches = parseRgJson(result.stdout, limit);
      const files = new Set(matches.map((match) => match.file));
      const truncated = matches.length >= limit;
      const text = ["code-search", `query: ${params.query}`, `path: ${displayPath(root, cwd)}`, params.glob ? `glob: ${params.glob}` : undefined, `matches: ${matches.length}${truncated ? "+" : ""}`, `files: ${files.size}`, `truncated: ${truncated}`, "└── results", ...formatSearchMatches(matches)].filter((line): line is string => typeof line === "string").join("\n");
      return { content: [{ type: "text", text }], details: { root, cwd, query: params.query, returned: matches.length, files: files.size, limit, truncated } };
    },
    renderCall(args, theme) { return renderToolCall("code-search", JSON.stringify(args.query ?? ""), theme); },
    renderResult(result, { expanded }, theme) { return renderToolResult(result.content.find((item) => item.type === "text")?.text ?? "", 4, expanded, theme); },
  });

  pi.registerTool({
    name: "code-files",
    label: "Code Files",
    description: "List file paths by glob or type. fd-backed with rg/git fallbacks. Use instead of ls/find.",
    promptSnippet: "Use code-files for file path listing instead of bash ls or find.",
    promptGuidelines: ["Use code-files for file path discovery. Never use bash ls or find.", "Use code-overview for first repo orientation; code-files for specific path enumeration."],
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
      return { content: [{ type: "text", text }], details: { root, searchDir, returned: files.length, truncated, via } };
    },
    renderCall(args, theme) { return renderToolCall("code-files", [args.path ?? ".", args.glob, args.type].filter(Boolean).join(" · "), theme); },
    renderResult(result, { expanded }, theme) { return renderToolResult(result.content.find((item) => item.type === "text")?.text ?? "", 4, expanded, theme); },
  });
}
