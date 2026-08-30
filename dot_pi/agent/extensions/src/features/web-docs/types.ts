export const SEARCH_TYPES = ["auto", "fast", "instant", "deep-lite", "deep", "deep-reasoning"] as const;
export const FETCH_MODES = ["markdown", "text", "html"] as const;

export const USER_AGENT = "pi-web-docs-extension/0.1";
export const ADMIN_BASE = "https://admin-api.exa.ai/team-management";
export const MAX_FETCH_BYTES = 2 * 1024 * 1024;
export const MAX_REDIRECTS = 5;

export type SearchType = (typeof SEARCH_TYPES)[number];
export type FetchMode = (typeof FETCH_MODES)[number];

export type ExaSearchResult = {
  title?: string | null;
  url: string;
  publishedDate?: string | null;
  author?: string | null;
  highlights?: string[] | null;
  text?: string | null;
  score?: number | null;
  id?: string | null;
};

export type ListApiKeysResponse = {
  apiKeys?: Array<{
    id: string;
    budgetCents?: number | null;
    isOverBudget?: boolean;
  }>;
};

export type UsageResponse = {
  total_cost_usd?: number;
};
