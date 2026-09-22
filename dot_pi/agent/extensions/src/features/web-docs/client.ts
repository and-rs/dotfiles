import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  truncateHead,
} from "@earendil-works/pi-coding-agent";

export const SEARCH_TYPES = [
  "auto",
  "fast",
  "instant",
  "deep-lite",
  "deep",
  "deep-reasoning",
] as const;

export const RECENCY = ["day", "week", "month", "year"] as const;

export const CATEGORIES = [
  "company",
  "people",
  "publication",
  "news",
  "personal site",
  "financial report",
] as const;

export type SearchType = (typeof SEARCH_TYPES)[number];
export type Recency = (typeof RECENCY)[number];

export type ExaResult = {
  title?: string | null;
  url: string;
  publishedDate?: string | null;
  author?: string | null;
  highlights?: string[] | null;
  text?: string | null;
  score?: number | null;
  subpages?: ExaResult[] | null;
};

type ExaSearchResponse = {
  results?: ExaResult[];
  requestId?: string;
  searchTime?: number;
  costDollars?: { total?: number };
};

type ExaContentsResponse = {
  results?: ExaResult[];
  statuses?: Array<{ id?: string; status?: string; error?: string }>;
  requestId?: string;
  searchTime?: number;
  costDollars?: { total?: number };
};

type ListApiKeysResponse = {
  apiKeys?: Array<{
    id: string;
    budgetCents?: number | null;
    isOverBudget?: boolean;
  }>;
};

type UsageResponse = { total_cost_usd?: number };

const EXA_API = "https://api.exa.ai";
const ADMIN_BASE = "https://admin-api.exa.ai/team-management";
const REQUEST_TIMEOUT_MS = 30_000;
const MAX_OUTPUT_BYTES = Math.floor(DEFAULT_MAX_BYTES * 0.9);

export function isSearchType(value: string): value is SearchType {
  return (SEARCH_TYPES as readonly string[]).includes(value);
}

export function isRecency(value: string): value is Recency {
  return (RECENCY as readonly string[]).includes(value);
}

export function displayUrl(url: string): string {
  try {
    const parsed = new URL(url);
    return (
      `${parsed.origin}${parsed.pathname}`.replace(/\/$/, "") || parsed.origin
    );
  } catch {
    return url;
  }
}

export function uniqueHosts(urls: string[]): string[] {
  const hosts: string[] = [];
  const seen = new Set<string>();
  for (const url of urls) {
    try {
      const host = new URL(url).hostname;
      if (seen.has(host)) continue;
      seen.add(host);
      hosts.push(host);
    } catch {
      // skip bad urls
    }
  }
  return hosts;
}

function isoDaysAgo(days: number): string {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
}

function recencyToPublishedDate(recency: Recency): string {
  let days = 365;
  if (recency === "day") days = 1;
  else if (recency === "week") days = 7;
  else if (recency === "month") days = 30;
  return isoDaysAgo(days);
}

function formatHighlights(highlights: string[] | null | undefined): string {
  if (!highlights || highlights.length === 0) return "";
  return highlights
    .map(
      (highlight) =>
        `- ${highlight
          .replace(/\r/g, "")
          .replace(/\n{3,}/g, "\n\n")
          .trim()}`,
    )
    .join("\n");
}

function fmtUsd(value: number): string {
  return `$${value.toFixed(2)}`;
}

async function exaPost<T>(
  apiKey: string,
  path: string,
  body: Record<string, unknown>,
  signal?: AbortSignal,
): Promise<T> {
  const timeout = AbortSignal.timeout(REQUEST_TIMEOUT_MS);
  let combined = timeout;
  if (signal) combined = AbortSignal.any([signal, timeout]);
  const res = await fetch(`${EXA_API}${path}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      accept: "application/json",
    },
    body: JSON.stringify(body),
    signal: combined,
  });
  if (!res.ok) {
    const errText = (await res.text()).slice(0, 300);
    throw new Error(`Exa ${path} failed: HTTP ${res.status} ${errText}`);
  }
  return (await res.json()) as T;
}

async function adminGet<T>(url: string, apiKey: string): Promise<T> {
  const res = await fetch(url, {
    method: "GET",
    headers: { "x-api-key": apiKey, accept: "application/json" },
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return (await res.json()) as T;
}

export async function computeExaUsageSummary(apiKey: string): Promise<string> {
  const list = await adminGet<ListApiKeysResponse>(
    `${ADMIN_BASE}/api-keys`,
    apiKey,
  );
  let apiKeys: NonNullable<ListApiKeysResponse["apiKeys"]> = [];
  if (Array.isArray(list.apiKeys)) apiKeys = list.apiKeys;
  if (apiKeys.length === 0) return "EXA no-api-keys";
  const startDate = encodeURIComponent(isoDaysAgo(30));
  const totals = await Promise.all(
    apiKeys.map(async (item) => {
      const usage = await adminGet<UsageResponse>(
        `${ADMIN_BASE}/api-keys/${item.id}/usage?start_date=${startDate}`,
        apiKey,
      );
      let totalCost = 0;
      if (typeof usage.total_cost_usd === "number") {
        totalCost = usage.total_cost_usd;
      }
      return totalCost;
    }),
  );
  const totalCost = totals.reduce((sum, value) => sum + value, 0);
  const overBudget = apiKeys.some((item) => item.isOverBudget);
  let budgetLabel = "";
  if (overBudget) budgetLabel = " · over-budget";
  return `EXA 30d ${fmtUsd(totalCost)} · keys ${apiKeys.length}${budgetLabel}`;
}

export type SearchParams = {
  query: string;
  type: SearchType;
  numResults: number;
  includeDomains?: string[];
  excludeDomains?: string[];
  category?: string;
  recency?: Recency;
  includeText?: boolean;
  maxCharacters?: number;
};

export type SearchOutcome = {
  results: ExaResult[];
  requestId?: string;
  searchTimeMs?: number;
  costUsd?: number;
  text: string;
};

export async function runExaSearch(
  apiKey: string,
  params: SearchParams,
  signal?: AbortSignal,
): Promise<SearchOutcome> {
  const contents: Record<string, unknown> = { highlights: true };
  if (params.includeText) {
    contents.text = {
      maxCharacters: params.maxCharacters ?? 2000,
    };
  }
  const body: Record<string, unknown> = {
    query: params.query,
    type: params.type,
    numResults: params.numResults,
    contents,
  };
  if (params.includeDomains?.length)
    body.includeDomains = params.includeDomains;
  if (params.excludeDomains?.length)
    body.excludeDomains = params.excludeDomains;
  if (params.category?.trim()) body.category = params.category.trim();
  if (params.recency)
    body.startPublishedDate = recencyToPublishedDate(params.recency);

  const response = await exaPost<ExaSearchResponse>(
    apiKey,
    "/search",
    body,
    signal,
  );
  let results: ExaResult[] = [];
  if (Array.isArray(response.results)) results = response.results;
  const meta: { costUsd?: number; searchTimeMs?: number } = {};
  if (typeof response.costDollars?.total === "number") {
    meta.costUsd = response.costDollars.total;
  }
  if (typeof response.searchTime === "number") {
    meta.searchTimeMs = response.searchTime;
  }
  const outcome: SearchOutcome = {
    results,
    text: buildSearchText(params, results, meta),
  };
  if (response.requestId) outcome.requestId = response.requestId;
  if (meta.searchTimeMs !== undefined) outcome.searchTimeMs = meta.searchTimeMs;
  if (meta.costUsd !== undefined) outcome.costUsd = meta.costUsd;
  return outcome;
}

export type FetchParams = {
  urls: string[];
  maxCharacters: number;
  maxAgeHours?: number;
  subpages?: number;
  subpageTarget?: string[];
  highlightsQuery?: string;
};

export type FetchOutcome = {
  results: ExaResult[];
  okCount: number;
  truncCount: number;
  requestId?: string;
  searchTimeMs?: number;
  costUsd?: number;
  text: string;
};

export async function runExaContents(
  apiKey: string,
  params: FetchParams,
  signal?: AbortSignal,
): Promise<FetchOutcome> {
  const body: Record<string, unknown> = {
    urls: params.urls,
    text: { maxCharacters: params.maxCharacters },
  };
  if (params.highlightsQuery?.trim()) {
    body.highlights = { query: params.highlightsQuery.trim() };
  }
  if (typeof params.maxAgeHours === "number")
    body.maxAgeHours = params.maxAgeHours;
  if (typeof params.subpages === "number" && params.subpages > 0)
    body.subpages = params.subpages;
  if (params.subpageTarget?.length) body.subpageTarget = params.subpageTarget;

  const response = await exaPost<ExaContentsResponse>(
    apiKey,
    "/contents",
    body,
    signal,
  );
  let results: ExaResult[] = [];
  if (Array.isArray(response.results)) results = response.results;

  let truncCount = 0;
  const blocks: string[] = [];
  for (const [index, result] of results.entries()) {
    const title = result.title?.trim() || result.url;
    const lines = [`### ${index + 1}. ${title}`, result.url];
    if (result.publishedDate) lines.push(`Published: ${result.publishedDate}`);
    if (result.author) lines.push(`Author: ${result.author}`);
    const highlights = formatHighlights(result.highlights);
    if (highlights) {
      lines.push("Highlights:");
      lines.push(highlights);
    }
    if (result.text?.trim()) {
      const text = result.text.trim();
      if (text.length >= params.maxCharacters) truncCount += 1;
      lines.push("", text);
    }
    if (result.subpages?.length) {
      lines.push("", "Subpages:");
      for (const sub of result.subpages) {
        lines.push(`#### ${sub.title?.trim() || sub.url}`, sub.url);
        if (sub.text?.trim()) lines.push(sub.text.trim());
      }
    }
    blocks.push(lines.join("\n"));
  }

  let raw = `Fetch: ${results.length} page(s)\n\n${blocks.join("\n\n---\n\n")}`;
  if (results.length === 0) raw = `No content for: ${params.urls.join(" ")}`;
  const trimmed = await clampToolText(raw);

  const outcome: FetchOutcome = {
    results,
    okCount: results.length,
    truncCount,
    text: trimmed.text,
  };
  if (response.requestId) outcome.requestId = response.requestId;
  if (typeof response.searchTime === "number") {
    outcome.searchTimeMs = response.searchTime;
  }
  if (typeof response.costDollars?.total === "number") {
    outcome.costUsd = response.costDollars.total;
  }
  return outcome;
}

function buildSearchText(
  params: SearchParams,
  results: ExaResult[],
  meta: { costUsd?: number; searchTimeMs?: number },
): string {
  if (results.length === 0) return `No results for: ${params.query}`;
  let category = null;
  if (params.category) category = `Category: ${params.category}`;
  let recency = null;
  if (params.recency) recency = `Recency: ${params.recency}`;
  let domains = null;
  if (params.includeDomains?.length)
    domains = `Include: ${params.includeDomains.join(", ")}`;
  let searchTime = null;
  if (typeof meta.searchTimeMs === "number")
    searchTime = `Time: ${Math.round(meta.searchTimeMs)}ms`;
  let cost = null;
  if (typeof meta.costUsd === "number") cost = `Cost: ${fmtUsd(meta.costUsd)}`;
  const header = [
    `Query: ${params.query}`,
    `Type: ${params.type}`,
    category,
    recency,
    domains,
    searchTime,
    cost,
    "",
  ]
    .filter((line) => line !== null)
    .join("\n");

  const body = results
    .map((result, index) => {
      const lines = [
        `${index + 1}. ${result.title?.trim() || result.url}`,
        `URL: ${result.url}`,
      ];
      if (result.publishedDate)
        lines.push(`Published: ${result.publishedDate}`);
      if (result.author) lines.push(`Author: ${result.author}`);
      if (typeof result.score === "number")
        lines.push(`Score: ${result.score}`);
      const highlights = formatHighlights(result.highlights);
      if (highlights) {
        lines.push("Highlights:");
        lines.push(highlights);
      }
      if (result.text?.trim()) {
        lines.push("", result.text.trim());
      }
      return lines.join("\n");
    })
    .join("\n\n");

  return `${header}\n${body}`.trim();
}

export async function clampToolText(
  body: string,
): Promise<{ text: string; truncated: boolean }> {
  const tr = truncateHead(body, {
    maxLines: DEFAULT_MAX_LINES,
    maxBytes: MAX_OUTPUT_BYTES,
  });
  if (!tr.truncated) return { text: body, truncated: false };
  let shown = tr.content;
  if (!shown) {
    shown = `${Buffer.from(body, "utf8").subarray(0, MAX_OUTPUT_BYTES).toString("utf8").trimEnd()}\n…`;
  }
  return {
    text: `${shown.trimEnd()}\n\n[truncated to pi tool output cap]`,
    truncated: true,
  };
}

export function parseUrlList(value: string | string[] | undefined): string[] {
  if (!value) return [];
  let raw: string[];
  if (Array.isArray(value)) raw = value;
  else raw = value.split(/[\s,]+/);
  const urls: string[] = [];
  for (const item of raw) {
    const trimmed = item.trim();
    if (!trimmed) continue;
    if (!URL.canParse(trimmed)) {
      throw new Error(`Invalid URL: ${trimmed}`);
    }
    const parsed = new URL(trimmed);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      throw new Error(`Unsupported URL protocol: ${parsed.protocol}`);
    }
    urls.push(trimmed);
  }
  return urls;
}

export function parseDomainList(
  value: string[] | undefined,
): string[] | undefined {
  if (!value?.length) return undefined;
  const list = value
    .map((item) =>
      item
        .trim()
        .replace(/^https?:\/\//, "")
        .replace(/\/$/, ""),
    )
    .filter(Boolean);
  if (list.length) return list;
  return undefined;
}
