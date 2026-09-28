import { readFileSync } from "node:fs";
import { mkdir, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import {
  getAgentDir,
  type ProviderModelConfig,
} from "@earendil-works/pi-coding-agent";
import type { CuratedModel } from "./catalog.ts";

export type SavedProvider = {
  id: string;
  name: string;
  baseUrl: string;
  /** Curated models to register; when absent, the full catalog is registered. */
  models?: CuratedModel[];
};

type LoadResult = {
  providers: SavedProvider[];
  error?: string;
};

let endpoints: SavedProvider[] = [];
let configError: string | undefined;

export function savedEndpoints(): readonly SavedProvider[] {
  return endpoints;
}

export function savedProvider(id: string): SavedProvider | undefined {
  return endpoints.find((entry) => entry.id === id);
}

export function configErrorMessage(): string | undefined {
  return configError;
}

export function loadSavedEndpoints(): void {
  const loaded = readProviders();
  endpoints = loaded.providers;
  configError = loaded.error;
}

export async function rememberProvider(
  entry: SavedProvider,
  models: ProviderModelConfig[],
): Promise<void> {
  const next = endpoints.filter((item) => item.id !== entry.id);
  next.push(entry);
  await writeCatalog(entry.id, models);
  await writeProviders(next);
  endpoints = next;
  configError = undefined;
}

export async function forgetProvider(id: string): Promise<void> {
  const next = endpoints.filter((entry) => entry.id !== id);
  await writeProviders(next);
  await rm(catalogPath(id), { force: true });
  endpoints = next;
}

export async function saveCatalog(
  id: string,
  models: ProviderModelConfig[],
): Promise<void> {
  await writeCatalog(id, models);
}

export function readCatalog(id: string): ProviderModelConfig[] {
  try {
    const parsed = JSON.parse(readFileSync(catalogPath(id), "utf8")) as unknown;
    if (!Array.isArray(parsed)) return [];
    const models: ProviderModelConfig[] = [];
    for (const entry of parsed) {
      if (isModelConfig(entry)) models.push(entry);
    }
    return models;
  } catch (error) {
    const nodeError = error as NodeJS.ErrnoException;
    if (nodeError.code === "ENOENT") return [];
    return [];
  }
}

function readProviders(): LoadResult {
  try {
    const parsed = JSON.parse(readFileSync(providersPath(), "utf8")) as unknown;
    return { providers: parseProviders(parsed) };
  } catch (error) {
    const nodeError = error as NodeJS.ErrnoException;
    if (nodeError.code === "ENOENT") return { providers: [] };
    let message = String(error);
    if (error instanceof Error) message = error.message;
    return {
      providers: [],
      error: `Model discovery config is invalid: ${message}`,
    };
  }
}

function parseProviders(payload: unknown): SavedProvider[] {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("providers.json must contain an object");
  }
  const providers = (payload as { providers?: unknown }).providers;
  if (!Array.isArray(providers)) {
    throw new Error("providers.json is missing providers");
  }
  const parsed: SavedProvider[] = [];
  for (const entry of providers) parsed.push(parseProvider(entry));
  return parsed;
}

function parseProvider(entry: unknown): SavedProvider {
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
    throw new Error("provider entry must be an object");
  }
  const record = entry as Record<string, unknown>;
  if (typeof record.id !== "string" || !record.id) {
    throw new Error("provider entry is missing id");
  }
  if (typeof record.name !== "string" || !record.name) {
    throw new Error(`provider ${record.id} is missing name`);
  }
  const baseUrl = readBaseUrl(record, `provider ${record.id}`);
  const models = readCuratedModels(record, `provider ${record.id}`);
  const provider: SavedProvider = { id: record.id, name: record.name, baseUrl };
  if (models) provider.models = models;
  return provider;
}

function readBaseUrl(record: Record<string, unknown>, label: string): string {
  if (typeof record.baseUrl !== "string" || !record.baseUrl) {
    throw new Error(`${label} is missing baseUrl`);
  }
  return record.baseUrl;
}

function readCuratedModels(
  record: Record<string, unknown>,
  label: string,
): CuratedModel[] | undefined {
  if (!Object.hasOwn(record, "models")) return undefined;
  if (!Array.isArray(record.models)) {
    throw new Error(`${label} has invalid models`);
  }
  const curated: CuratedModel[] = [];
  for (const entry of record.models) {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
      throw new Error(`${label} has an invalid models entry`);
    }
    const model = entry as Record<string, unknown>;
    if (typeof model.sourceId !== "string" || !model.sourceId) {
      throw new Error(`${label} has a models entry missing sourceId`);
    }
    if (typeof model.name !== "string" || !model.name) {
      throw new Error(`${label} has a models entry missing name`);
    }
    const reasoning = readReasoning(model, `${label} model ${model.sourceId}`);
    curated.push({
      sourceId: model.sourceId,
      name: model.name,
      reasoning,
    });
  }
  return curated;
}

/** Reads the reasoning flag; migrates legacy `thinking` level strings. */
function readReasoning(model: Record<string, unknown>, label: string): boolean {
  if (typeof model.reasoning === "boolean") return model.reasoning;
  if (typeof model.thinking === "string" && model.thinking !== "") {
    return model.thinking !== "off";
  }
  throw new Error(`${label} is missing reasoning`);
}

function isModelConfig(entry: unknown): entry is ProviderModelConfig {
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) return false;
  const record = entry as Record<string, unknown>;
  return typeof record.id === "string" && typeof record.name === "string";
}

async function writeProviders(
  providers: readonly SavedProvider[],
): Promise<void> {
  await mkdir(discoveryDir(), { recursive: true, mode: 0o700 });
  await writeFile(
    providersPath(),
    `${JSON.stringify({ providers }, null, 2)}\n`,
    {
      mode: 0o600,
    },
  );
}

async function writeCatalog(
  id: string,
  models: readonly ProviderModelConfig[],
): Promise<void> {
  const directory = join(discoveryDir(), "catalogs");
  await mkdir(directory, { recursive: true, mode: 0o700 });
  await writeFile(
    join(directory, `${id}.json`),
    `${JSON.stringify(models, null, 2)}\n`,
    {
      mode: 0o600,
    },
  );
}

function providersPath(): string {
  return join(discoveryDir(), "providers.json");
}

function catalogPath(id: string): string {
  return join(discoveryDir(), "catalogs", `${id}.json`);
}

function discoveryDir(): string {
  return join(getAgentDir(), "model-discovery");
}
