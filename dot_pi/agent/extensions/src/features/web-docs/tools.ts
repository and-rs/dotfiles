import { defineTool, type Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { resolveExaKey } from "./auth.ts";
import {
  CATEGORIES,
  clampToolText,
  displayUrl,
  type ExaResult,
  type FetchParams,
  isRecency,
  isSearchType,
  parseDomainList,
  parseUrlList,
  RECENCY,
  runExaContents,
  runExaSearch,
  SEARCH_TYPES,
  type SearchParams,
  type SearchType,
  uniqueHosts,
} from "./client.ts";

const SEP = " 🭳 ";
const END = " ▕";
const MAX_URL_LINES = 3;

type SearchArgs = {
  query?: unknown;
  type?: unknown;
  numResults?: unknown;
  includeDomains?: unknown;
  excludeDomains?: unknown;
  category?: unknown;
  recency?: unknown;
};

type FetchArgs = {
  urls?: unknown;
  url?: unknown;
  maxAgeHours?: unknown;
  subpages?: unknown;
};

function joinFields(fields: Array<string | null | undefined>): string {
  return fields.filter((field): field is string => Boolean(field)).join(SEP);
}

function metaBar(
  theme: Theme,
  fields: Array<string | null | undefined>,
): string {
  return theme.bg("selectedBg", `${joinFields(fields)}${END}`);
}

function accentLines(theme: Theme, lines: string[]): string {
  if (lines.length === 0) return "";
  const shown = lines.slice(0, MAX_URL_LINES);
  const extra = lines.length - shown.length;
  const painted = shown.map((line) => theme.fg("accent", line));
  if (extra > 0) painted.push(theme.fg("dim", `+${extra} more`));
  return painted.join("\n");
}

function chrome(
  theme: Theme,
  fields: Array<string | null | undefined>,
  below: string[] = [],
): Text {
  const bar = metaBar(theme, fields);
  const body = accentLines(theme, below);
  return new Text(body ? `${bar}\n${body}` : bar, 0, 0);
}

function fmtMs(ms: number | undefined): string | null {
  if (typeof ms !== "number" || !Number.isFinite(ms)) return null;
  return `${Math.round(ms)}ms`;
}

function fmtCost(cost: number | undefined): string | null {
  if (typeof cost !== "number" || !Number.isFinite(cost)) return null;
  return `$${cost.toFixed(2)}`;
}

function domainField(
  includeDomains?: string[] | null,
  excludeDomains?: string[] | null,
): string | null {
  if (includeDomains?.length) return `in:${includeDomains[0]}`;
  if (excludeDomains?.length) return `ex:${excludeDomains[0]}`;
  return null;
}

function shortFail(text: string | undefined): string {
  if (!text?.trim()) return "failed";
  const lower = text.toLowerCase();
  if (lower.includes("no exa api key") || lower.includes("no exa key")) {
    return "no Exa key";
  }
  if (lower.includes("provide url")) return "no url";
  if (lower.includes("invalid url")) return "bad url";
  const http = text.match(/HTTP\s+(\d+)/i);
  if (http) return `HTTP ${http[1]}`;
  return text.replace(/\s+/g, " ").trim().slice(0, 48);
}

function resultText(result: {
  content?: Array<{ type?: string; text?: string }>;
}): string | undefined {
  for (const part of result.content ?? []) {
    if (part?.type === "text" && part.text?.trim()) return part.text.trim();
  }
  return undefined;
}

function searchArgFields(
  theme: Theme,
  args: SearchArgs,
): Array<string | null | undefined> {
  const includeDomains = parseDomainList(
    Array.isArray(args.includeDomains)
      ? (args.includeDomains as string[])
      : undefined,
  );
  const excludeDomains = parseDomainList(
    Array.isArray(args.excludeDomains)
      ? (args.excludeDomains as string[])
      : undefined,
  );
  const type =
    typeof args.type === "string" && isSearchType(args.type)
      ? args.type
      : "auto";
  const n =
    typeof args.numResults === "number" ? `n=${args.numResults}` : "n=5";
  const recency =
    typeof args.recency === "string" && isRecency(args.recency)
      ? args.recency
      : null;
  const category =
    typeof args.category === "string" && args.category.trim()
      ? args.category.trim()
      : null;
  return [
    theme.fg("toolTitle", theme.bold("web_search")),
    type,
    n,
    domainField(includeDomains, excludeDomains),
    category,
    recency,
  ];
}

function searchQueryLine(args: SearchArgs): string | null {
  return typeof args.query === "string" && args.query.trim()
    ? args.query.trim()
    : null;
}

function parseFetchUrls(args: FetchArgs): string[] {
  try {
    if (Array.isArray(args.urls)) return args.urls as string[];
    if (typeof args.url === "string") return parseUrlList(args.url);
  } catch {
    return [];
  }
  return [];
}

function fetchArgFields(
  theme: Theme,
  args: FetchArgs,
  urlCount: number,
): Array<string | null | undefined> {
  const age =
    typeof args.maxAgeHours === "number" ? `age<=${args.maxAgeHours}h` : null;
  const sub =
    typeof args.subpages === "number" && args.subpages > 0
      ? `sub=${args.subpages}`
      : null;
  return [
    theme.fg("toolTitle", theme.bold("web_fetch")),
    urlCount ? `${urlCount} urls` : null,
    age,
    sub,
  ];
}

export function returnRawWebTools() {
  return [
    defineTool({
      name: "web_search",
      label: "Web Search",
      description:
        "Search the web for documentation and relevant URLs using Exa.",
      promptSnippet:
        "Find authoritative web pages and docs URLs with Exa search.",
      promptGuidelines: [
        "Use web_search first when you need current docs, reference pages, or external URLs.",
        "Use web_fetch after web_search to read the exact page you chose.",
        "Prefer web_search with includeDomains when the user already knows the vendor or docs host.",
        "Use recency for news or time-bounded facts; use category when the source kind is clear.",
        "Skip web_fetch when highlights already answer the question.",
      ],
      parameters: Type.Object({
        query: Type.String({
          description: "Search query for the docs, API, error, or concept.",
        }),
        type: Type.Optional(
          Type.Union(
            SEARCH_TYPES.map((value) => Type.Literal(value)),
            { description: "Search depth and latency tradeoff. Default auto." },
          ),
        ),
        numResults: Type.Optional(
          Type.Integer({
            minimum: 1,
            maximum: 10,
            description: "How many results to return. Default 5.",
          }),
        ),
        includeDomains: Type.Optional(
          Type.Array(
            Type.String({
              description: "Domain or path prefix, for example docs.exa.ai",
            }),
            {
              maxItems: 10,
              description: "Only include results from these domains or paths.",
            },
          ),
        ),
        excludeDomains: Type.Optional(
          Type.Array(
            Type.String({ description: "Domain or path to exclude." }),
            {
              maxItems: 10,
              description: "Exclude results from these domains or paths.",
            },
          ),
        ),
        category: Type.Optional(
          Type.String({
            description: `Optional focus category. Known: ${CATEGORIES.join(", ")}.`,
          }),
        ),
        recency: Type.Optional(
          Type.Union(
            RECENCY.map((value) => Type.Literal(value)),
            {
              description:
                "Only results published within this window: day, week, month, year.",
            },
          ),
        ),
        includeText: Type.Optional(
          Type.Boolean({
            description:
              "Also return page text (costlier). Default false — highlights only.",
          }),
        ),
        maxCharacters: Type.Optional(
          Type.Integer({
            minimum: 500,
            maximum: 10000,
            description:
              "Per-result text cap when includeText is true. Default 2000.",
          }),
        ),
      }),
      execute: async (_toolCallId, params, signal) => {
        const resolved = await resolveExaKey("api");
        if (!resolved.key) {
          throw new Error("No Exa API key. Use /exa login or set EXA_API_KEY.");
        }
        const rawType = params.type ?? "auto";
        const type: SearchType = isSearchType(rawType) ? rawType : "auto";
        const numResults =
          typeof params.numResults === "number" ? params.numResults : 5;
        const includeDomains = parseDomainList(params.includeDomains);
        const excludeDomains = parseDomainList(params.excludeDomains);
        const rawRecency = params.recency;
        const recency =
          typeof rawRecency === "string" && isRecency(rawRecency)
            ? rawRecency
            : undefined;

        const searchParams: SearchParams = {
          query: params.query,
          type,
          numResults,
          includeText: params.includeText === true,
        };
        if (includeDomains) searchParams.includeDomains = includeDomains;
        if (excludeDomains) searchParams.excludeDomains = excludeDomains;
        if (params.category?.trim())
          searchParams.category = params.category.trim();
        if (recency) searchParams.recency = recency;
        if (typeof params.maxCharacters === "number") {
          searchParams.maxCharacters = params.maxCharacters;
        }

        const outcome = await runExaSearch(resolved.key, searchParams, signal);
        const clamped = await clampToolText(outcome.text);
        const urls = outcome.results.map((result) => result.url);

        return {
          content: [{ type: "text", text: clamped.text }],
          details: {
            query: params.query,
            type,
            numResults,
            includeDomains: includeDomains ?? null,
            excludeDomains: excludeDomains ?? null,
            category: params.category ?? null,
            recency: recency ?? null,
            source: resolved.source,
            requestId: outcome.requestId ?? null,
            searchTimeMs: outcome.searchTimeMs ?? null,
            costUsd: outcome.costUsd ?? null,
            truncated: clamped.truncated,
            urls,
            hosts: uniqueHosts(urls),
            results: outcome.results,
          },
        };
      },
      renderCall(args, theme) {
        const query = searchQueryLine(args);
        return chrome(
          theme,
          searchArgFields(theme, args),
          query ? [query] : [],
        );
      },
      renderResult(result, { isPartial }, theme, context) {
        const args = (context?.args ?? {}) as SearchArgs;
        const details = result.details as
          | {
              urls?: string[];
              hosts?: string[];
              searchTimeMs?: number | null;
              costUsd?: number | null;
              truncated?: boolean;
              query?: string;
            }
          | undefined;
        const query = details?.query?.trim() || searchQueryLine(args) || null;
        const base = searchArgFields(theme, {
          ...args,
          type: details?.urls ? args.type : args.type,
        });

        if (isPartial) {
          return chrome(
            theme,
            [...base, theme.fg("warning", "searching…")],
            query ? [query] : [],
          );
        }

        if (context?.isError) {
          return chrome(
            theme,
            [
              ...base,
              theme.fg("error", "fail"),
              theme.fg("error", shortFail(resultText(result))),
            ],
            query ? [query] : [],
          );
        }

        const urls = details?.urls ?? [];
        const hostCount = details?.hosts?.length ?? uniqueHosts(urls).length;
        const outcome =
          urls.length === 0
            ? [theme.fg("warning", "0 hits"), theme.fg("warning", "empty")]
            : [
                theme.fg("success", `${urls.length} hits`),
                hostCount ? `${hostCount} hosts` : null,
                fmtMs(details?.searchTimeMs ?? undefined),
                fmtCost(details?.costUsd ?? undefined),
                details?.truncated ? "trunc" : null,
              ];

        return chrome(theme, [...base, ...outcome], urls.map(displayUrl));
      },
    }),

    defineTool({
      name: "web_fetch",
      label: "Web Fetch",
      description:
        "Fetch clean page content for known URLs via Exa (live-crawl aware).",
      promptSnippet: "Fetch and extract readable content from known URL(s).",
      promptGuidelines: [
        "Use web_fetch only after you already know the URL you want to inspect.",
        "Pass multiple docs URLs in one call when related.",
        "Use subpages/subpageTarget for doc hubs that split content across linked pages.",
        "Keep maxCharacters small unless the user needs a long dump.",
      ],
      parameters: Type.Object({
        urls: Type.Optional(
          Type.Array(Type.String({ description: "Absolute http(s) URL." }), {
            minItems: 1,
            maxItems: 5,
            description: "One or more URLs to fetch.",
          }),
        ),
        url: Type.Optional(
          Type.String({
            description:
              "Single URL, or several separated by space/comma (alias for urls).",
          }),
        ),
        maxCharacters: Type.Optional(
          Type.Integer({
            minimum: 1000,
            maximum: 50000,
            description: "Maximum characters per page text. Default 5000.",
          }),
        ),
        maxAgeHours: Type.Optional(
          Type.Integer({
            minimum: -1,
            maximum: 720,
            description:
              "Content freshness: -1 cache only, 0 always live, N use cache if newer than N hours.",
          }),
        ),
        subpages: Type.Optional(
          Type.Integer({
            minimum: 0,
            maximum: 10,
            description: "Crawl up to N linked subpages per URL.",
          }),
        ),
        subpageTarget: Type.Optional(
          Type.Array(Type.String({ description: "Section name, e.g. docs" }), {
            maxItems: 10,
            description: "Preferred subpage section names.",
          }),
        ),
        highlightsQuery: Type.Optional(
          Type.String({
            description: "Focus query for highlights on fetched pages.",
          }),
        ),
      }),
      execute: async (_toolCallId, params, signal) => {
        const resolved = await resolveExaKey("api");
        if (!resolved.key) {
          throw new Error("No Exa API key. Use /exa login or set EXA_API_KEY.");
        }
        const fromArray = Array.isArray(params.urls) ? params.urls : [];
        const fromAlias =
          typeof params.url === "string" ? parseUrlList(params.url) : [];
        const urls = [...fromArray, ...fromAlias];
        if (urls.length === 0) throw new Error("Provide url or urls.");
        for (const item of urls) {
          if (!URL.canParse(item)) throw new Error(`Invalid URL: ${item}`);
        }
        const maxCharacters =
          typeof params.maxCharacters === "number"
            ? params.maxCharacters
            : 5000;
        const fetchParams: FetchParams = { urls, maxCharacters };
        if (typeof params.maxAgeHours === "number") {
          fetchParams.maxAgeHours = params.maxAgeHours;
        }
        if (typeof params.subpages === "number") {
          fetchParams.subpages = params.subpages;
        }
        if (params.subpageTarget?.length) {
          fetchParams.subpageTarget = params.subpageTarget;
        }
        if (params.highlightsQuery?.trim()) {
          fetchParams.highlightsQuery = params.highlightsQuery.trim();
        }
        const outcome = await runExaContents(resolved.key, fetchParams, signal);
        return {
          content: [{ type: "text", text: outcome.text }],
          details: {
            urls,
            okCount: outcome.okCount,
            truncCount: outcome.truncCount,
            maxCharacters,
            maxAgeHours: params.maxAgeHours ?? null,
            subpages: params.subpages ?? null,
            source: resolved.source,
            requestId: outcome.requestId ?? null,
            searchTimeMs: outcome.searchTimeMs ?? null,
            costUsd: outcome.costUsd ?? null,
            results: outcome.results,
          },
        };
      },
      renderCall(args, theme) {
        const urls = parseFetchUrls(args);
        return chrome(
          theme,
          fetchArgFields(theme, args, urls.length),
          urls.map(displayUrl),
        );
      },
      renderResult(result, { isPartial }, theme, context) {
        const args = (context?.args ?? {}) as FetchArgs;
        const details = result.details as
          | {
              urls?: string[];
              okCount?: number;
              truncCount?: number;
              results?: ExaResult[];
            }
          | undefined;
        const urls =
          details?.urls ??
          details?.results?.map((item) => item.url) ??
          parseFetchUrls(args);
        const base = fetchArgFields(theme, args, urls.length);

        if (isPartial) {
          return chrome(
            theme,
            [...base, theme.fg("warning", "fetching…")],
            urls.map(displayUrl),
          );
        }

        if (context?.isError) {
          return chrome(
            theme,
            [
              ...base,
              theme.fg("error", "fail"),
              theme.fg("error", shortFail(resultText(result))),
            ],
            urls.map(displayUrl),
          );
        }

        const ok = details?.okCount ?? urls.length;
        const trunc = details?.truncCount ?? 0;
        const outcome =
          ok === 0
            ? [theme.fg("warning", "ok 0"), theme.fg("warning", "empty")]
            : [
                theme.fg("success", `ok ${ok}`),
                trunc > 0 ? `trunc ${trunc}` : null,
              ];

        return chrome(theme, [...base, ...outcome], urls.map(displayUrl));
      },
    }),
  ];
}
