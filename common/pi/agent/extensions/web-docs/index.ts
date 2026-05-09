import { exec as execCallback } from "node:child_process";
import { chmod, mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { promisify } from "node:util";

import { Text } from "@earendil-works/pi-tui";
import { Readability } from "@mozilla/readability";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import Exa from "exa-js";
import { JSDOM } from "jsdom";
import TurndownService from "turndown";
import { gfm } from "turndown-plugin-gfm";
import { Type } from "typebox";

const exec = promisify(execCallback);
const SEARCH_TYPES = ["auto", "fast", "instant", "deep-lite", "deep", "deep-reasoning"] as const;
const FETCH_MODES = ["markdown", "text", "html"] as const;
const AUTH_PATH = join(homedir(), ".pi", "agent", "auth.json");
const USER_AGENT = "pi-web-docs-extension/0.1";

type SearchType = (typeof SEARCH_TYPES)[number];
type FetchMode = (typeof FETCH_MODES)[number];

type AuthRecord = Record<string, unknown>;

type ApiKeyEntry = {
  type?: string;
  key?: string;
};

type ExaSearchResult = {
  title?: string | null;
  url: string;
  publishedDate?: string | null;
  author?: string | null;
  highlights?: string[] | null;
  text?: string | null;
  score?: number | null;
  id?: string | null;
};

function isSearchType(value: string): value is SearchType {
  return SEARCH_TYPES.includes(value as SearchType);
}

function isFetchMode(value: string): value is FetchMode {
  return FETCH_MODES.includes(value as FetchMode);
}

function truncate(value: string, maxCharacters: number): { text: string; truncated: boolean } {
  if (value.length <= maxCharacters) {
    return { text: value, truncated: false };
  }

  return {
    text: `${value.slice(0, Math.max(0, maxCharacters - 16)).trimEnd()}\n\n[truncated]`,
    truncated: true,
  };
}

function normalizeWhitespace(value: string): string {
  return value.replace(/\r/g, "").replace(/\n{3,}/g, "\n\n").trim();
}

function formatHighlights(highlights: string[] | null | undefined): string {
  if (!highlights || highlights.length === 0) {
    return "";
  }

  return highlights.map((highlight) => `- ${normalizeWhitespace(highlight)}`).join("\n");
}

function buildTurndown(): TurndownService {
  const service = new TurndownService({
    codeBlockStyle: "fenced",
    headingStyle: "atx",
    bulletListMarker: "-",
  });

  service.use(gfm);
  return service;
}

function parseHtmlDocument(html: string, url: string): {
  title: string | null;
  markdown: string;
  text: string;
  html: string;
} {
  const dom = new JSDOM(html, { url });
  const title = dom.window.document.title.trim() || null;
  const article = new Readability(dom.window.document).parse();
  const sourceHtml = article?.content?.trim() || dom.window.document.body?.innerHTML?.trim() || html;
  const sourceText = article?.textContent?.trim() || dom.window.document.body?.textContent?.trim() || "";
  const turndown = buildTurndown();
  const markdown = normalizeWhitespace(turndown.turndown(sourceHtml || html));
  const text = normalizeWhitespace(sourceText);

  if (markdown.length >= 200) {
    return { title, markdown, text, html: sourceHtml || html };
  }

  const bodyHtml = dom.window.document.body?.innerHTML?.trim() || sourceHtml || html;
  const bodyText = normalizeWhitespace(dom.window.document.body?.textContent?.trim() || sourceText);
  const fallbackMarkdown = normalizeWhitespace(turndown.turndown(bodyHtml));

  return {
    title,
    markdown: fallbackMarkdown || markdown,
    text: bodyText || text,
    html: bodyHtml,
  };
}

async function readAuthFile(): Promise<AuthRecord> {
  try {
    const raw = await readFile(AUTH_PATH, "utf8");
    const parsed = JSON.parse(raw) as unknown;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("auth.json must contain an object");
    }
    return parsed as AuthRecord;
  } catch (error) {
    const nodeError = error as NodeJS.ErrnoException;
    if (nodeError.code === "ENOENT") {
      return {};
    }
    throw error;
  }
}

async function writeAuthFile(data: AuthRecord): Promise<void> {
  await mkdir(dirname(AUTH_PATH), { recursive: true, mode: 0o700 });
  await writeFile(AUTH_PATH, `${JSON.stringify(data, null, 2)}\n`, { mode: 0o600 });
  await chmod(AUTH_PATH, 0o600);
}

async function resolveStoredKeyValue(value: string): Promise<string> {
  const trimmed = value.trim();
  if (!trimmed) {
    return "";
  }

  if (trimmed.startsWith("!")) {
    const command = trimmed.slice(1).trim();
    if (!command) {
      return "";
    }
    const { stdout } = await exec(command, { shell: "/bin/sh" });
    return stdout.trim();
  }

  if (/^[A-Z][A-Z0-9_]*$/.test(trimmed) && process.env[trimmed]) {
    return process.env[trimmed]?.trim() ?? "";
  }

  return trimmed;
}

async function getStoredExaEntry(): Promise<ApiKeyEntry | null> {
  const auth = await readAuthFile();
  const entry = auth.exa as ApiKeyEntry | undefined;
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
    return null;
  }
  return entry;
}

async function resolveExaApiKey(): Promise<{ key: string | null; source: "auth" | "env" | null }> {
  const stored = await getStoredExaEntry();
  if (stored?.type === "api_key" && typeof stored.key === "string") {
    const resolved = await resolveStoredKeyValue(stored.key);
    if (resolved) {
      return { key: resolved, source: "auth" };
    }
  }

  const envKey = process.env.EXA_API_KEY?.trim();
  if (envKey) {
    return { key: envKey, source: "env" };
  }

  return { key: null, source: null };
}

async function saveExaApiKey(key: string): Promise<void> {
  const auth = await readAuthFile();
  auth.exa = { type: "api_key", key: key.trim() };
  await writeAuthFile(auth);
}

async function clearExaApiKey(): Promise<boolean> {
  const auth = await readAuthFile();
  if (!("exa" in auth)) {
    return false;
  }
  delete auth.exa;
  await writeAuthFile(auth);
  return true;
}

function summarizeUrlHost(url: string): string {
  try {
    return new URL(url).hostname;
  } catch {
    return url;
  }
}

function buildSearchText(query: string, type: SearchType, results: ExaSearchResult[]): string {
  if (results.length === 0) {
    return `No results for: ${query}`;
  }

  const lines = [`Query: ${query}`, `Type: ${type}`, ""];

  for (const [index, result] of results.entries()) {
    lines.push(`${index + 1}. ${result.title?.trim() || result.url}`);
    lines.push(`URL: ${result.url}`);
    if (result.publishedDate) {
      lines.push(`Published: ${result.publishedDate}`);
    }
    if (result.author) {
      lines.push(`Author: ${result.author}`);
    }
    if (typeof result.score === "number") {
      lines.push(`Score: ${result.score}`);
    }
    const highlights = formatHighlights(result.highlights);
    if (highlights) {
      lines.push("Highlights:");
      lines.push(highlights);
    }
    lines.push("");
  }

  return lines.join("\n").trim();
}

async function fetchUrlContent(
  url: string,
  mode: FetchMode,
  maxCharacters: number,
  timeoutMs: number,
  signal?: AbortSignal,
): Promise<{
  text: string;
  details: {
    url: string;
    finalUrl: string;
    title: string | null;
    contentType: string;
    status: number;
    mode: FetchMode;
    truncated: boolean;
  };
}> {
  const timeoutSignal = AbortSignal.timeout(timeoutMs);
  const combinedSignal = signal ? AbortSignal.any([signal, timeoutSignal]) : timeoutSignal;
  const response = await fetch(url, {
    headers: {
      Accept: "text/html,application/xhtml+xml,application/json,text/plain;q=0.9,*/*;q=0.8",
      "User-Agent": USER_AGENT,
    },
    redirect: "follow",
    signal: combinedSignal,
  });

  if (!response.ok) {
    throw new Error(`Fetch failed: ${response.status} ${response.statusText}`);
  }

  const finalUrl = response.url;
  const contentType = response.headers.get("content-type")?.toLowerCase() || "";
  const body = await response.text();
  let title: string | null = null;
  let extracted = "";

  if (contentType.includes("text/html") || contentType.includes("application/xhtml+xml")) {
    const parsed = parseHtmlDocument(body, finalUrl);
    title = parsed.title;
    extracted = mode === "html" ? parsed.html : mode === "text" ? parsed.text : parsed.markdown || parsed.text;
  } else if (contentType.includes("application/json")) {
    const parsed = JSON.parse(body) as unknown;
    extracted = JSON.stringify(parsed, null, 2);
  } else if (
    contentType.startsWith("text/") ||
    contentType.includes("application/xml") ||
    contentType.includes("application/javascript")
  ) {
    extracted = body;
  } else {
    throw new Error(`Unsupported content type: ${contentType || "unknown"}`);
  }

  const cleaned = normalizeWhitespace(extracted);
  const truncated = truncate(cleaned, maxCharacters);
  const prefix = [title ? `Title: ${title}` : null, `URL: ${finalUrl}`, ""].filter(Boolean).join("\n");

  return {
    text: `${prefix}${truncated.text}`.trim(),
    details: {
      url,
      finalUrl,
      title,
      contentType,
      status: response.status,
      mode,
      truncated: truncated.truncated,
    },
  };
}

export default function webDocsExtension(pi: ExtensionAPI) {
  pi.registerCommand("exa", {
    description: "Configure Exa API key for web search",
    getArgumentCompletions: (prefix) => {
      const items = ["login", "status", "logout"];
      return items.filter((item) => item.startsWith(prefix)).map((value) => ({ value, label: value }));
    },
    handler: async (args, ctx) => {
      let action = args.trim().toLowerCase();

      if (!action) {
        const choice = await ctx.ui.select("Exa", ["login", "status", "logout"]);
        if (!choice) {
          ctx.ui.notify("Cancelled", "info");
          return;
        }
        action = choice;
      }

      if (action === "login") {
        const value = await ctx.ui.input("Exa API key", "exa_...");
        if (!value?.trim()) {
          ctx.ui.notify("No key saved", "info");
          return;
        }
        await saveExaApiKey(value);
        ctx.ui.notify(`Saved Exa key to ${AUTH_PATH}`, "info");
        return;
      }

      if (action === "status") {
        const resolved = await resolveExaApiKey();
        if (!resolved.key || !resolved.source) {
          ctx.ui.notify("Exa not configured", "warning");
          return;
        }
        const source = resolved.source === "auth" ? AUTH_PATH : "EXA_API_KEY env";
        ctx.ui.notify(`Exa configured via ${source}`, "info");
        return;
      }

      if (action === "logout") {
        const cleared = await clearExaApiKey();
        ctx.ui.notify(cleared ? "Removed stored Exa key" : "No stored Exa key", "info");
        return;
      }

      ctx.ui.notify("Usage: /exa [login|status|logout]", "error");
    },
  });

  pi.registerTool({
    name: "exa_search",
    label: "Exa Search",
    description: "Search the web for documentation and relevant URLs using Exa.",
    promptSnippet: "Find authoritative web pages and docs URLs with Exa search.",
    promptGuidelines: [
      "Use exa_search first when you need to find current docs, reference pages, or external URLs.",
      "Use web_fetch after exa_search to read the exact page you chose.",
      "Prefer exa_search with includeDomains when the user already knows the vendor or docs host.",
    ],
    parameters: Type.Object({
      query: Type.String({ description: "Search query for the docs, API, error, or concept." }),
      type: Type.Optional(
        Type.Union(SEARCH_TYPES.map((value) => Type.Literal(value)), { description: "Search depth and latency tradeoff." }),
      ),
      numResults: Type.Optional(
        Type.Integer({ minimum: 1, maximum: 10, description: "How many results to return. Default 5." }),
      ),
      includeDomains: Type.Optional(
        Type.Array(Type.String({ description: "Domain to prefer, for example docs.exa.ai" }), {
          maxItems: 10,
          description: "Only include results from these domains.",
        }),
      ),
      excludeDomains: Type.Optional(
        Type.Array(Type.String({ description: "Domain to exclude." }), {
          maxItems: 10,
          description: "Exclude results from these domains.",
        }),
      ),
    }),
    execute: async (_toolCallId, params) => {
      const resolved = await resolveExaApiKey();
      if (!resolved.key) {
        throw new Error("No Exa API key. Use /exa login or set EXA_API_KEY.");
      }

      const type = isSearchType(params.type ?? "") ? params.type : "auto";
      const numResults = typeof params.numResults === "number" ? params.numResults : 5;
      const exa = new Exa(resolved.key);
      const response = (await exa.search(params.query, {
        type,
        numResults,
        contents: { highlights: true },
        includeDomains: params.includeDomains,
        excludeDomains: params.excludeDomains,
      })) as { results?: ExaSearchResult[] };
      const results = Array.isArray(response.results) ? response.results : [];
      const text = buildSearchText(params.query, type, results);

      return {
        content: [{ type: "text", text }],
        details: {
          query: params.query,
          type,
          numResults,
          source: resolved.source,
          results,
        },
      };
    },
    renderCall(args, theme) {
      return new Text(
        `${theme.fg("toolTitle", theme.bold("exa_search"))} ${theme.fg("accent", JSON.stringify(args.query ?? ""))}`,
        0,
        0,
      );
    },
    renderResult(result, { expanded, isPartial }, theme) {
      if (isPartial) {
        return new Text(theme.fg("warning", "Searching..."), 0, 0);
      }

      const details = result.details as { results?: ExaSearchResult[]; type?: SearchType } | undefined;
      const results = details?.results ?? [];

      if (!expanded) {
        const first = results[0];
        const summary = results.length === 0
          ? "0 results"
          : `${results.length} result${results.length === 1 ? "" : "s"} · ${summarizeUrlHost(first.url)}`;
        return new Text(theme.fg("success", summary), 0, 0);
      }

      const textContent = result.content.find((content) => content.type === "text");
      if (!textContent || textContent.type !== "text") {
        return new Text("", 0, 0);
      }

      return new Text(`\n${theme.fg("toolOutput", textContent.text)}`, 0, 0);
    },
  });

  pi.registerTool({
    name: "web_fetch",
    label: "Web Fetch",
    description: "Fetch a URL directly and extract readable content.",
    promptSnippet: "Fetch and extract readable content from a known URL.",
    promptGuidelines: [
      "Use web_fetch only after you already know the URL you want to inspect.",
      "Use web_fetch with mode markdown or text for docs pages; use html only when structure matters.",
      "Keep web_fetch maxCharacters small unless the user explicitly needs a long page dump.",
    ],
    parameters: Type.Object({
      url: Type.String({ description: "Full URL to fetch." }),
      mode: Type.Optional(
        Type.Union(FETCH_MODES.map((value) => Type.Literal(value)), {
          description: "Returned format: markdown, text, or html. Default markdown.",
        }),
      ),
      maxCharacters: Type.Optional(
        Type.Integer({ minimum: 1000, maximum: 50000, description: "Maximum characters in returned content. Default 12000." }),
      ),
      timeoutMs: Type.Optional(
        Type.Integer({ minimum: 1000, maximum: 60000, description: "Network timeout in milliseconds. Default 15000." }),
      ),
    }),
    execute: async (_toolCallId, params, signal) => {
      if (!URL.canParse(params.url)) {
        throw new Error(`Invalid URL: ${params.url}`);
      }

      const mode = isFetchMode(params.mode ?? "") ? params.mode : "markdown";
      const maxCharacters = typeof params.maxCharacters === "number" ? params.maxCharacters : 12000;
      const timeoutMs = typeof params.timeoutMs === "number" ? params.timeoutMs : 15000;
      const result = await fetchUrlContent(params.url, mode, maxCharacters, timeoutMs, signal);

      return {
        content: [{ type: "text", text: result.text }],
        details: result.details,
      };
    },
    renderCall(args, theme) {
      return new Text(
        `${theme.fg("toolTitle", theme.bold("web_fetch"))} ${theme.fg("accent", summarizeUrlHost(args.url ?? ""))}`,
        0,
        0,
      );
    },
    renderResult(result, { expanded, isPartial }, theme) {
      if (isPartial) {
        return new Text(theme.fg("warning", "Fetching..."), 0, 0);
      }

      const details = result.details as {
        finalUrl?: string;
        title?: string | null;
        mode?: FetchMode;
        truncated?: boolean;
      } | undefined;

      if (!expanded) {
        const host = details?.finalUrl ? summarizeUrlHost(details.finalUrl) : "done";
        const suffix = details?.truncated ? " · truncated" : "";
        return new Text(theme.fg("success", `${host}${suffix}`), 0, 0);
      }

      const textContent = result.content.find((content) => content.type === "text");
      if (!textContent || textContent.type !== "text") {
        return new Text("", 0, 0);
      }

      return new Text(`\n${theme.fg("toolOutput", textContent.text)}`, 0, 0);
    },
  });
}
