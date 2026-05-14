import { Text } from "@earendil-works/pi-tui";
import { lookup } from "node:dns/promises";
import { isIP } from "node:net";
import { Readability } from "@mozilla/readability";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Exa } from "exa-js";
import { JSDOM } from "jsdom";
import TurndownService from "turndown";
import { gfm } from "turndown-plugin-gfm";
import { Type } from "typebox";

import { AUTH_PATH, clearExaKey, formatExaSource, resolveExaKey, saveExaKey } from "../lib/exa-auth.ts";

const SEARCH_TYPES = ["auto", "fast", "instant", "deep-lite", "deep", "deep-reasoning"] as const;
const FETCH_MODES = ["markdown", "text", "html"] as const;

const USER_AGENT = "pi-web-docs-extension/0.1";
const ADMIN_BASE = "https://admin-api.exa.ai/team-management";
const MAX_FETCH_BYTES = 2 * 1024 * 1024;
const MAX_REDIRECTS = 5;

type SearchType = (typeof SEARCH_TYPES)[number];
type FetchMode = (typeof FETCH_MODES)[number];

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

type ListApiKeysResponse = {
  apiKeys?: Array<{
    id: string;
    budgetCents?: number | null;
    isOverBudget?: boolean;
  }>;
};

type UsageResponse = {
  total_cost_usd?: number;
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

function isoDaysAgo(days: number): string {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
}

function isPrivateIPv4(address: string): boolean {
  const parts = address.split(".").map((part) => Number.parseInt(part, 10));
  if (parts.length !== 4 || parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) return true;
  const [a, b] = parts;
  return (
    a === 0 ||
    a === 10 ||
    a === 127 ||
    (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 168) ||
    a >= 224
  );
}

function isPrivateIPv6(address: string): boolean {
  const normalized = address.toLowerCase();
  if (normalized.startsWith("::ffff:")) return isPrivateIPv4(normalized.slice(7));
  return (
    normalized === "::" ||
    normalized === "::1" ||
    normalized.startsWith("fc") ||
    normalized.startsWith("fd") ||
    normalized.startsWith("fe80:")
  );
}

function isPrivateAddress(address: string): boolean {
  const family = isIP(address);
  if (family === 4) return isPrivateIPv4(address);
  if (family === 6) return isPrivateIPv6(address);
  return true;
}

async function assertPublicHttpUrl(urlText: string): Promise<void> {
  const url = new URL(urlText);
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error(`Unsupported URL protocol: ${url.protocol}. Use http or https.`);
  }

  const hostname = url.hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (hostname === "localhost" || hostname.endsWith(".localhost")) {
    throw new Error(`Blocked local URL host: ${url.hostname}`);
  }

  if (isIP(hostname)) {
    if (isPrivateAddress(hostname)) throw new Error(`Blocked private URL host: ${url.hostname}`);
    return;
  }

  const addresses = await lookup(hostname, { all: true, verbatim: true });
  if (addresses.length === 0 || addresses.some((entry) => isPrivateAddress(entry.address))) {
    throw new Error(`Blocked URL host resolving to private address: ${url.hostname}`);
  }
}

async function fetchPublicUrl(url: string, init: RequestInit): Promise<Response> {
  let currentUrl = url;
  for (let redirectCount = 0; redirectCount <= MAX_REDIRECTS; redirectCount++) {
    await assertPublicHttpUrl(currentUrl);
    const response = await fetch(currentUrl, { ...init, redirect: "manual" });
    if (![301, 302, 303, 307, 308].includes(response.status)) return response;

    const location = response.headers.get("location");
    if (!location) return response;
    currentUrl = new URL(location, currentUrl).toString();
  }
  throw new Error(`Too many redirects fetching URL: ${url}`);
}

async function readResponseTextCapped(response: Response, maxBytes: number): Promise<{ text: string; truncated: boolean }> {
  if (!response.body) return { text: "", truncated: false };
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let text = "";
  let bytesRead = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    const remaining = maxBytes - bytesRead;
    if (remaining <= 0) {
      await reader.cancel();
      return { text: `${text}${decoder.decode()}`, truncated: true };
    }
    if (value.byteLength > remaining) {
      text += decoder.decode(value.slice(0, remaining), { stream: true });
      await reader.cancel();
      return { text: `${text}${decoder.decode()}`, truncated: true };
    }
    bytesRead += value.byteLength;
    text += decoder.decode(value, { stream: true });
  }

  return { text: `${text}${decoder.decode()}`, truncated: false };
}

function fmtUsd(value: number): string {
  return `$${value.toFixed(2)}`;
}

async function fetchJson<T>(url: string, apiKey: string): Promise<T> {
  const res = await fetch(url, {
    method: "GET",
    headers: {
      "x-api-key": apiKey,
      accept: "application/json",
    },
  });

  if (!res.ok) {
    throw new Error(`HTTP ${res.status}`);
  }

  return (await res.json()) as T;
}

async function computeExaUsageSummary(apiKey: string): Promise<string> {
  const list = await fetchJson<ListApiKeysResponse>(`${ADMIN_BASE}/api-keys`, apiKey);
  const apiKeys = Array.isArray(list.apiKeys) ? list.apiKeys : [];

  if (apiKeys.length === 0) {
    return "EXA no-api-keys";
  }

  const startDate = encodeURIComponent(isoDaysAgo(30));
  const totals = await Promise.all(
    apiKeys.map(async (item) => {
      const usage = await fetchJson<UsageResponse>(
        `${ADMIN_BASE}/api-keys/${item.id}/usage?start_date=${startDate}`,
        apiKey,
      );
      return typeof usage.total_cost_usd === "number" ? usage.total_cost_usd : 0;
    }),
  );

  const totalUsd = totals.reduce((acc, value) => acc + value, 0);
  const budgetCents = apiKeys.reduce((acc, item) => acc + (typeof item.budgetCents === "number" ? item.budgetCents : 0), 0);
  const anyBudget = apiKeys.some((item) => typeof item.budgetCents === "number");
  const anyOver = apiKeys.some((item) => item.isOverBudget === true);

  if (!anyBudget) {
    return `EXA 30d ${fmtUsd(totalUsd)}`;
  }

  const budgetUsd = budgetCents / 100;
  const remaining = budgetUsd - totalUsd;
  const status = anyOver || remaining < 0 ? "over" : "left";
  return `EXA 30d ${fmtUsd(totalUsd)} ${status} ${fmtUsd(Math.abs(remaining))}`;
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
  const response = await fetchPublicUrl(url, {
    headers: {
      Accept: "text/html,application/xhtml+xml,application/json,text/plain;q=0.9,*/*;q=0.8",
      "User-Agent": USER_AGENT,
    },
    signal: combinedSignal,
  });

  if (!response.ok) {
    throw new Error(`Fetch failed: ${response.status} ${response.statusText}`);
  }

  await assertPublicHttpUrl(response.url);
  const finalUrl = response.url;
  const contentType = response.headers.get("content-type")?.toLowerCase() || "";
  const cappedBody = await readResponseTextCapped(response, MAX_FETCH_BYTES);
  const body = cappedBody.text;
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
      truncated: truncated.truncated || cappedBody.truncated,
    },
  };
}

export default function webDocsExtension(pi: ExtensionAPI) {
  pi.registerCommand("exa", {
    description: "Configure Exa API key for web search",
    getArgumentCompletions: (prefix) => {
      const items = ["login", "status", "logout", "service-login", "service-status", "service-logout", "usage"];
      return items.filter((item) => item.startsWith(prefix)).map((value) => ({ value, label: value }));
    },
    handler: async (args, ctx) => {
      let action = args.trim().toLowerCase();

      if (!action) {
        const choice = await ctx.ui.select("Exa", ["login", "status", "logout", "service-login", "service-status", "service-logout", "usage"]);
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
        await saveExaKey("api", value);
        ctx.ui.notify(`Saved Exa key to ${AUTH_PATH}`, "info");
        return;
      }

      if (action === "service-login") {
        const value = await ctx.ui.input("Exa service API key", "exa_...");
        if (!value?.trim()) {
          ctx.ui.notify("No service key saved", "info");
          return;
        }
        await saveExaKey("service", value);
        ctx.ui.notify(`Saved Exa service key to ${AUTH_PATH}`, "info");
        return;
      }

      if (action === "status") {
        const resolved = await resolveExaKey("api");
        if (!resolved.key || !resolved.source) {
          ctx.ui.notify("Exa not configured", "warning");
          return;
        }
        ctx.ui.notify(`Exa configured via ${formatExaSource("api", resolved.source)}`, "info");
        return;
      }

      if (action === "service-status") {
        const resolved = await resolveExaKey("service");
        if (!resolved.key || !resolved.source) {
          ctx.ui.notify("Exa service key not configured", "warning");
          return;
        }
        ctx.ui.notify(`Exa service key configured via ${formatExaSource("service", resolved.source)}`, "info");
        return;
      }

      if (action === "usage") {
        const resolved = await resolveExaKey("service");
        if (!resolved.key) {
          ctx.ui.notify("Exa service key not configured. Use /exa service-login.", "warning");
          return;
        }

        try {
          ctx.ui.notify(await computeExaUsageSummary(resolved.key), "info");
        } catch (error) {
          const message = error instanceof Error ? error.message : "unknown error";
          ctx.ui.notify(`Exa usage unavailable: ${message}`, "error");
        }
        return;
      }

      if (action === "logout") {
        const cleared = await clearExaKey("api");
        ctx.ui.notify(cleared ? "Removed stored Exa key" : "No stored Exa key", "info");
        return;
      }

      if (action === "service-logout") {
        const cleared = await clearExaKey("service");
        ctx.ui.notify(cleared ? "Removed stored Exa service key" : "No stored Exa service key", "info");
        return;
      }

      ctx.ui.notify("Usage: /exa [login|status|logout|service-login|service-status|service-logout|usage]", "error");
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
      const resolved = await resolveExaKey("api");
      if (!resolved.key) {
        throw new Error("No Exa API key. Use /exa login or set EXA_API_KEY.");
      }

      const type = isSearchType(params.type ?? "") ? params.type : "auto";
      const numResults = typeof params.numResults === "number" ? params.numResults : 5;
      const exa = new Exa(resolved.key) as unknown as {
        search: (query: string, options: Record<string, unknown>) => Promise<unknown>;
      };
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
