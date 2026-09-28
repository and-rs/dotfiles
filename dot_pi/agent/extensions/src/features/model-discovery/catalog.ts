import type { ProviderModelConfig } from "@earendil-works/pi-coding-agent";

const DEFAULT_CONTEXT_WINDOW = 128000;
const DEFAULT_MAX_TOKENS = 16384;
const REQUEST_TIMEOUT_MS = 15000;
const ZERO_COST = {
  input: 0,
  output: 0,
  cacheRead: 0,
  cacheWrite: 0,
};

const CONTEXT_KEYS = ["context_window", "contextWindow", "context_length"];
const MAX_TOKEN_KEYS = ["max_tokens", "maxTokens", "max_completion_tokens"];

export type CuratedModel = {
  /** Model id in the fetched catalog. */
  sourceId: string;
  /** User-provided canonical display name. */
  name: string;
  /** User-declared thinking capability. */
  reasoning: boolean;
};

export type CuratedBuildResult = {
  configs: ProviderModelConfig[];
  /** Curated sourceIds with no match in the catalog. */
  missing: string[];
};

/** Keep fetched catalog metadata separate from curation and provider behavior. */
export function baseCatalogConfigs(
  models: readonly ProviderModelConfig[],
): ProviderModelConfig[] {
  return models.map((model) => ({
    id: model.id,
    name: model.name,
    reasoning: false,
    input: ["text"],
    cost: model.cost,
    contextWindow: model.contextWindow,
    maxTokens: model.maxTokens,
    compat: {
      supportsDeveloperRole: false,
      supportsReasoningEffort: false,
    },
  }));
}

/** Build registered model configs from curated entries joined with catalog metadata. */
export function buildCuratedConfigs(
  catalog: readonly ProviderModelConfig[],
  curated: readonly CuratedModel[],
): CuratedBuildResult {
  const byId = new Map(
    baseCatalogConfigs(catalog).map((model) => [model.id, model]),
  );
  const configs: ProviderModelConfig[] = [];
  const missing: string[] = [];
  for (const entry of curated) {
    const base = byId.get(entry.sourceId);
    if (!base) {
      missing.push(entry.sourceId);
      continue;
    }
    configs.push({
      ...base,
      name: entry.name,
      reasoning: entry.reasoning,
      compat: {
        supportsDeveloperRole: false,
        supportsReasoningEffort: entry.reasoning,
      },
    });
  }
  return { configs, missing };
}

export function normalizeBaseUrl(value: string): string {
  const trimmed = value.trim().replace(/\/+$/, "");
  let url: URL;
  try {
    url = new URL(trimmed);
  } catch {
    throw new Error("Base URL must be an http(s) URL.");
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error("Base URL must be an http(s) URL.");
  }
  if (url.username || url.password) {
    throw new Error("Base URL must not include credentials.");
  }
  return url.toString().replace(/\/$/, "");
}

export function mapCatalog(payload: unknown): ProviderModelConfig[] {
  const models: ProviderModelConfig[] = [];
  for (const entry of readData(payload)) {
    const model = mapEntry(entry);
    if (model) models.push(model);
  }
  return models;
}

export async function fetchTextModels(
  baseUrl: string,
  signal?: AbortSignal,
): Promise<ProviderModelConfig[]> {
  const root = normalizeBaseUrl(baseUrl);
  const timeout = AbortSignal.timeout(REQUEST_TIMEOUT_MS);
  let combined = timeout;
  if (signal) combined = AbortSignal.any([signal, timeout]);
  const response = await fetch(`${root}/models`, {
    headers: { accept: "application/json" },
    signal: combined,
  });
  if (!response.ok) {
    const detail = (await response.text()).slice(0, 180);
    throw new Error(`Model list failed: HTTP ${response.status} ${detail}`);
  }
  const models = mapCatalog(await response.json());
  if (models.length === 0) {
    throw new Error("Model list has no text models.");
  }
  return models;
}

function readData(payload: unknown): unknown[] {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("Model list must be an object with a data array.");
  }
  const data = (payload as { data?: unknown }).data;
  if (!Array.isArray(data)) {
    throw new Error("Model list must be an object with a data array.");
  }
  return data;
}

function mapEntry(entry: unknown): ProviderModelConfig | undefined {
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
    return undefined;
  }
  const record = entry as Record<string, unknown>;
  if (!isTextModel(record)) return undefined;
  const id = readId(record);
  if (!id) return undefined;
  return {
    id,
    name: readName(record, id),
    reasoning: false,
    input: ["text"],
    cost: ZERO_COST,
    contextWindow: readPositive(record, CONTEXT_KEYS) ?? DEFAULT_CONTEXT_WINDOW,
    maxTokens: readPositive(record, MAX_TOKEN_KEYS) ?? DEFAULT_MAX_TOKENS,
    compat: {
      supportsDeveloperRole: false,
      supportsReasoningEffort: false,
    },
  };
}

function isTextModel(record: Record<string, unknown>): boolean {
  if (!Object.hasOwn(record, "type")) return true;
  return record.type === "text";
}

function readId(record: Record<string, unknown>): string | undefined {
  if (typeof record.id !== "string") return undefined;
  const id = record.id.trim();
  if (!id) return undefined;
  return id;
}

function readName(record: Record<string, unknown>, id: string): string {
  if (typeof record.name !== "string") return id;
  const name = record.name.trim();
  if (!name) return id;
  return name;
}

function readPositive(
  record: Record<string, unknown>,
  keys: readonly string[],
): number | undefined {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "number" && Number.isFinite(value) && value > 0) {
      return value;
    }
  }
  return undefined;
}
