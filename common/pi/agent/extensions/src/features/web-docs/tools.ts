import { Text } from "@earendil-works/pi-tui";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { resolveExaKey } from "./lib/exa-auth.ts";
import { buildSearchText, runExaSearch, summarizeUrlHost } from "./exa.ts";
import { fetchUrlContent } from "./web-fetch.ts";
import { FETCH_MODES, SEARCH_TYPES, type ExaSearchResult, type FetchMode, type SearchType } from "./types.ts";
import { isFetchMode, isSearchType } from "./shared.ts";

export function registerWebDocsTools(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "exa-search",
    label: "Exa Search",
    description: "Search the web for documentation and relevant URLs using Exa.",
    promptSnippet: "Find authoritative web pages and docs URLs with Exa search.",
    promptGuidelines: [
      "Use exa-search first when you need to find current docs, reference pages, or external URLs.",
      "Use web-fetch after exa-search to read the exact page you chose.",
      "Prefer exa-search with includeDomains when the user already knows the vendor or docs host.",
    ],
    parameters: Type.Object({
      query: Type.String({ description: "Search query for the docs, API, error, or concept." }),
      type: Type.Optional(Type.Union(SEARCH_TYPES.map((value) => Type.Literal(value)), { description: "Search depth and latency tradeoff." })),
      numResults: Type.Optional(Type.Integer({ minimum: 1, maximum: 10, description: "How many results to return. Default 5." })),
      includeDomains: Type.Optional(Type.Array(Type.String({ description: "Domain to prefer, for example docs.exa.ai" }), { maxItems: 10, description: "Only include results from these domains." })),
      excludeDomains: Type.Optional(Type.Array(Type.String({ description: "Domain to exclude." }), { maxItems: 10, description: "Exclude results from these domains." })),
    }),
    execute: async (_toolCallId, params) => {
      const resolved = await resolveExaKey("api");
      if (!resolved.key) throw new Error("No Exa API key. Use /exa login or set EXA_API_KEY.");
      const type = isSearchType(params.type ?? "") ? params.type : "auto";
      const numResults = typeof params.numResults === "number" ? params.numResults : 5;
      const results = await runExaSearch(resolved.key, params.query, type, numResults, params.includeDomains, params.excludeDomains);
      const text = buildSearchText(params.query, type, results);
      return { content: [{ type: "text", text }], details: { query: params.query, type, numResults, source: resolved.source, results } };
    },
    renderCall(args, theme) {
      return new Text(`${theme.fg("toolTitle", theme.bold("exa-search"))} ${theme.fg("accent", JSON.stringify(args.query ?? ""))}`, 0, 0);
    },
    renderResult(result, { expanded, isPartial }, theme) {
      if (isPartial) return new Text(theme.fg("warning", "Searching..."), 0, 0);
      const details = result.details as { results?: ExaSearchResult[]; type?: SearchType } | undefined;
      const results = details?.results ?? [];
      if (!expanded) {
        const first = results[0];
        const summary = results.length === 0 ? "0 results" : `${results.length} result${results.length === 1 ? "" : "s"} · ${summarizeUrlHost(first.url)}`;
        return new Text(theme.fg("success", summary), 0, 0);
      }
      const textContent = result.content.find((content) => content.type === "text");
      if (!textContent || textContent.type !== "text") return new Text("", 0, 0);
      return new Text(`\n${theme.fg("toolOutput", textContent.text)}`, 0, 0);
    },
  });

  pi.registerTool({
    name: "web-fetch",
    label: "Web Fetch",
    description: "Fetch a URL directly and extract readable content.",
    promptSnippet: "Fetch and extract readable content from a known URL.",
    promptGuidelines: [
      "Use web-fetch only after you already know the URL you want to inspect.",
      "Use web-fetch with mode markdown or text for docs pages; use html only when structure matters.",
      "Keep web-fetch maxCharacters small unless the user explicitly needs a long page dump.",
    ],
    parameters: Type.Object({
      url: Type.String({ description: "Full URL to fetch." }),
      mode: Type.Optional(Type.Union(FETCH_MODES.map((value) => Type.Literal(value)), { description: "Returned format: markdown, text, or html. Default markdown." })),
      maxCharacters: Type.Optional(Type.Integer({ minimum: 1000, maximum: 50000, description: "Maximum characters in returned content. Default 12000." })),
      timeoutMs: Type.Optional(Type.Integer({ minimum: 1000, maximum: 60000, description: "Network timeout in milliseconds. Default 15000." })),
    }),
    execute: async (_toolCallId, params, signal) => {
      if (!URL.canParse(params.url)) throw new Error(`Invalid URL: ${params.url}`);
      const mode = isFetchMode(params.mode ?? "") ? params.mode : "markdown";
      const maxCharacters = typeof params.maxCharacters === "number" ? params.maxCharacters : 12000;
      const timeoutMs = typeof params.timeoutMs === "number" ? params.timeoutMs : 15000;
      const result = await fetchUrlContent(params.url, mode, maxCharacters, timeoutMs, signal);
      return { content: [{ type: "text", text: result.text }], details: result.details };
    },
    renderCall(args, theme) {
      return new Text(`${theme.fg("toolTitle", theme.bold("web-fetch"))} ${theme.fg("accent", summarizeUrlHost(args.url ?? ""))}`, 0, 0);
    },
    renderResult(result, { expanded, isPartial }, theme) {
      if (isPartial) return new Text(theme.fg("warning", "Fetching..."), 0, 0);
      const details = result.details as { finalUrl?: string; title?: string | null; mode?: FetchMode; truncated?: boolean } | undefined;
      if (!expanded) {
        const host = details?.finalUrl ? summarizeUrlHost(details.finalUrl) : "done";
        const suffix = details?.truncated ? " · truncated" : "";
        return new Text(theme.fg("success", `${host}${suffix}`), 0, 0);
      }
      const textContent = result.content.find((content) => content.type === "text");
      if (!textContent || textContent.type !== "text") return new Text("", 0, 0);
      return new Text(`\n${theme.fg("toolOutput", textContent.text)}`, 0, 0);
    },
  });
}
