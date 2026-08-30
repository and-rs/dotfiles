import { Exa } from "exa-js";
import { ADMIN_BASE, type ExaSearchResult, type ListApiKeysResponse, type SearchType, type UsageResponse } from "./types.ts";

function isoDaysAgo(days: number): string {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
}

function formatHighlights(highlights: string[] | null | undefined): string {
  if (!highlights || highlights.length === 0) return "";
  return highlights.map((highlight) => `- ${highlight.replace(/\r/g, "").replace(/\n{3,}/g, "\n\n").trim()}`).join("\n");
}

function fmtUsd(value: number): string {
  return `$${value.toFixed(2)}`;
}

async function fetchJson<T>(url: string, apiKey: string): Promise<T> {
  const res = await fetch(url, { method: "GET", headers: { "x-api-key": apiKey, accept: "application/json" } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return (await res.json()) as T;
}

export async function computeExaUsageSummary(apiKey: string): Promise<string> {
  const list = await fetchJson<ListApiKeysResponse>(`${ADMIN_BASE}/api-keys`, apiKey);
  const apiKeys = Array.isArray(list.apiKeys) ? list.apiKeys : [];
  if (apiKeys.length === 0) return "EXA no-api-keys";
  const startDate = encodeURIComponent(isoDaysAgo(30));
  const totals = await Promise.all(apiKeys.map(async (item) => {
    const usage = await fetchJson<UsageResponse>(`${ADMIN_BASE}/api-keys/${item.id}/usage?start_date=${startDate}`, apiKey);
    return typeof usage.total_cost_usd === "number" ? usage.total_cost_usd : 0;
  }));
  const totalCost = totals.reduce((sum, value) => sum + value, 0);
  const overBudget = apiKeys.some((item) => item.isOverBudget);
  return `EXA 30d ${fmtUsd(totalCost)} · keys ${apiKeys.length}${overBudget ? ' · over-budget' : ''}`;
}

export async function runExaSearch(apiKey: string, query: string, type: SearchType, numResults: number, includeDomains?: string[], excludeDomains?: string[]): Promise<ExaSearchResult[]> {
  const exa = new Exa(apiKey) as unknown as { search: (query: string, options: Record<string, unknown>) => Promise<unknown> };
  const response = (await exa.search(query, { type, numResults, contents: { highlights: true }, includeDomains, excludeDomains })) as { results?: ExaSearchResult[] };
  return Array.isArray(response.results) ? response.results : [];
}

export function summarizeUrlHost(url: string): string {
  try { return new URL(url).hostname; } catch { return url; }
}

export function buildSearchText(query: string, type: SearchType, results: ExaSearchResult[]): string {
  if (results.length === 0) return `No results for: ${query}`;
  const lines = [`Query: ${query}`, `Type: ${type}`, ""];
  for (const [index, result] of results.entries()) {
    lines.push(`${index + 1}. ${result.title?.trim() || result.url}`);
    lines.push(`URL: ${result.url}`);
    if (result.publishedDate) lines.push(`Published: ${result.publishedDate}`);
    if (result.author) lines.push(`Author: ${result.author}`);
    if (typeof result.score === "number") lines.push(`Score: ${result.score}`);
    const highlights = formatHighlights(result.highlights);
    if (highlights) {
      lines.push("Highlights:");
      lines.push(highlights);
    }
    lines.push("");
  }
  return lines.join("\n").trim();
}
