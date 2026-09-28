import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ProviderModelConfig,
} from "@earendil-works/pi-coding-agent";
import {
  baseCatalogConfigs,
  buildCuratedConfigs,
  type CuratedModel,
  fetchTextModels,
  normalizeBaseUrl,
} from "./catalog.ts";
import { occupiedProviderIds, providerIdError } from "./rules.ts";
import { refreshCuratedProviders } from "./startup.ts";
import {
  configErrorMessage,
  forgetProvider,
  loadSavedEndpoints,
  readCatalog,
  rememberProvider,
  type SavedProvider,
  saveCatalog,
  savedEndpoints,
  savedProvider,
} from "./store.ts";

const ACTIONS = ["add", "edit", "refresh", "remove"];

export default function registerModelDiscovery(pi: ExtensionAPI): void {
  loadSavedEndpoints();
  const error = configErrorMessage();
  const entries = [...savedEndpoints()];
  for (const entry of entries) {
    pi.registerProvider(entry.id, providerConfig(entry, readCatalog(entry.id)));
  }
  const startupRefresh = refreshCuratedProviders(entries, async (entry) => {
    const models = await fetchTextModels(entry.baseUrl);
    await saveCatalog(entry.id, models);
    pi.registerProvider(entry.id, providerConfig(entry, models));
  });
  pi.on("session_start", (_event, ctx) => {
    if (error) ctx.ui.notify(error, "warning");
    void startupRefresh.then((failures) => {
      for (const failure of failures) {
        ctx.ui.notify(
          `Startup model refresh failed for ${failure.id}: ${failure.message}. Using cached models if available.`,
          "warning",
        );
      }
    });
  });
  pi.registerCommand("providers", {
    description: "Manage custom OpenAI-compatible providers",
    getArgumentCompletions: (prefix) => completions(prefix),
    handler: (args, ctx) => handleCommand(pi, args, ctx),
  });
}

function providerConfig(entry: SavedProvider, models: ProviderModelConfig[]) {
  const registered = registeredFor(entry, models);
  return {
    name: entry.name,
    baseUrl: entry.baseUrl,
    api: "openai-completions" as const,
    models: registered,
    refreshModels: (context: { allowNetwork: boolean; signal?: AbortSignal }) =>
      refreshSaved(entry.id, context.allowNetwork, context.signal),
  };
}

async function refreshSaved(
  id: string,
  allowNetwork: boolean,
  signal?: AbortSignal,
): Promise<ProviderModelConfig[]> {
  const entry = savedProvider(id);
  if (!entry) throw new Error(`Provider ${id} is not saved.`);
  if (!allowNetwork) {
    const cached = readCatalog(id);
    if (cached.length === 0) throw new Error(`No cached models for ${id}.`);
    return registeredFor(entry, cached);
  }
  const models = await fetchTextModels(entry.baseUrl, signal);
  await saveCatalog(id, models);
  return registeredFor(entry, models);
}

/** Curated models when configured, otherwise the full catalog. */
function registeredFor(
  entry: SavedProvider,
  models: readonly ProviderModelConfig[],
): ProviderModelConfig[] {
  if (entry.models) return buildCuratedConfigs(models, entry.models).configs;
  return baseCatalogConfigs(models);
}

async function handleCommand(
  pi: ExtensionAPI,
  args: string,
  ctx: ExtensionCommandContext,
): Promise<void> {
  if (configErrorMessage()) {
    ctx.ui.notify(
      configErrorMessage() ?? "Model discovery config is invalid.",
      "error",
    );
    return;
  }
  const parsed = await parseArgs(args, ctx);
  if (!parsed) return;
  if (parsed.action === "add") {
    await addProvider(pi, ctx, parsed.id);
    return;
  }
  if (parsed.action === "edit") {
    await editProvider(pi, ctx, parsed.id);
    return;
  }
  if (parsed.action === "refresh") {
    await refreshProviders(pi, ctx, parsed.id);
    return;
  }
  if (parsed.action === "remove") {
    await removeProvider(pi, ctx, parsed.id);
  }
}

async function parseArgs(
  args: string,
  ctx: ExtensionCommandContext,
): Promise<{ action: string; id: string } | undefined> {
  const parts = args
    .trim()
    .split(/\s+/)
    .filter((part) => part.length > 0);
  let action = parts[0];
  let id = parts.slice(1).join(" ");
  if (!action) {
    const choice = await ctx.ui.select("Custom providers", ACTIONS);
    if (!choice) {
      ctx.ui.notify("Cancelled", "info");
      return undefined;
    }
    action = choice;
  }
  if (!ACTIONS.includes(action)) {
    ctx.ui.notify("Usage: /providers add|edit|refresh|remove [id]", "warning");
    return undefined;
  }
  if ((action === "remove" || action === "edit") && !id) {
    const ids = savedEndpoints().map((entry) => entry.id);
    if (ids.length === 0) {
      ctx.ui.notify("No custom providers.", "info");
      return undefined;
    }
    let title = "Edit provider";
    if (action === "remove") title = "Remove provider";
    const choice = await ctx.ui.select(title, ids);
    if (!choice) {
      ctx.ui.notify("Cancelled", "info");
      return undefined;
    }
    id = choice;
  }
  return { action, id };
}

async function addProvider(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  givenId: string,
): Promise<void> {
  let id = givenId;
  if (!id) {
    const value = await ctx.ui.input("Provider id", "provider");
    if (value === undefined) {
      ctx.ui.notify("Cancelled", "info");
      return;
    }
    id = value.trim();
  }
  const owned = new Set(savedEndpoints().map((entry) => entry.id));
  const occupied = occupiedProviderIds(ctx.modelRegistry.getAll());
  const idError = providerIdError(id, occupied, owned);
  if (idError) {
    ctx.ui.notify(idError, "warning");
    return;
  }
  const nameValue = await ctx.ui.input("Display name", id);
  if (nameValue === undefined) {
    ctx.ui.notify("Cancelled", "info");
    return;
  }
  let name = nameValue.trim();
  if (!name) name = id;
  const baseValue = await ctx.ui.input("API root URL", "https://host/v1");
  if (baseValue === undefined) {
    ctx.ui.notify("Cancelled", "info");
    return;
  }
  let baseUrl: string;
  try {
    baseUrl = normalizeBaseUrl(baseValue);
  } catch (error) {
    ctx.ui.notify(errorMessage(error), "warning");
    return;
  }
  let models: ProviderModelConfig[];
  try {
    models = await fetchTextModels(baseUrl, ctx.signal);
  } catch (error) {
    ctx.ui.notify(errorMessage(error), "error");
    return;
  }
  const curated = await curateModels(ctx, models, []);
  if (curated === undefined) {
    ctx.ui.notify("Cancelled", "info");
    return;
  }
  const entry: SavedProvider = { id, name, baseUrl };
  if (curated.length > 0) entry.models = curated;
  await rememberProvider(entry, models);
  pi.registerProvider(id, providerConfig(entry, models));
  let count = models.length;
  if (entry.models) {
    count = buildCuratedConfigs(models, entry.models).configs.length;
  }
  let hint =
    " No models selected, so all fetched models are registered; use /providers edit to curate.";
  if (entry.models) hint = "";
  ctx.ui.notify(
    `Added ${id} with ${count} models. Run /login ${id} before they appear in /model.${hint}`,
    "info",
  );
}

async function editProvider(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  id: string,
): Promise<void> {
  const entry = savedProvider(id);
  if (!entry) {
    ctx.ui.notify(`Provider ${id} is not saved.`, "warning");
    return;
  }
  const catalog = readCatalog(id);
  if (catalog.length === 0) {
    ctx.ui.notify(
      `No cached catalog for ${id}. Run /providers refresh ${id} first.`,
      "warning",
    );
    return;
  }
  const curated = await curateModels(ctx, catalog, entry.models ?? []);
  if (curated === undefined) {
    ctx.ui.notify("Cancelled", "info");
    return;
  }
  if (curated.length > 0) {
    const missing = buildCuratedConfigs(catalog, curated).missing;
    if (missing.length > 0) {
      ctx.ui.notify(
        `Not in catalog: ${missing.join(", ")}. Run /providers refresh ${id} if this is unexpected.`,
        "warning",
      );
    }
  }
  const next: SavedProvider = { ...entry };
  if (curated.length > 0) next.models = curated;
  else delete next.models;
  await rememberProvider(next, readCatalog(id));
  pi.registerProvider(next.id, providerConfig(next, readCatalog(next.id)));
  ctx.ui.notify(`Updated models for ${id}.`, "info");
}

async function curateModels(
  ctx: ExtensionCommandContext,
  catalog: readonly ProviderModelConfig[],
  existing: readonly CuratedModel[],
): Promise<CuratedModel[] | undefined> {
  const curated = [...existing];
  while (true) {
    let summary = "none selected (all models will be registered)";
    if (curated.length > 0) {
      summary = curated
        .map((entry) => {
          if (entry.reasoning) return `${entry.name} [thinking]`;
          return entry.name;
        })
        .join(", ");
    }
    const choice = await ctx.ui.select(`Curated models: ${summary}`, [
      "Add model",
      "Edit model",
      "Remove model",
      "Done",
    ]);
    if (!choice) return undefined;
    if (choice === "Done") return curated;
    if (choice === "Add model") {
      const taken = new Set(curated.map((entry) => entry.sourceId));
      const base = await pickCatalogModel(ctx, catalog, taken);
      if (base) {
        const added = await configureCuratedModel(ctx, base);
        if (added) curated.push(added);
      }
      continue;
    }
    if (curated.length === 0) {
      ctx.ui.notify("No curated models.", "info");
      continue;
    }
    const picked = await ctx.ui.select(
      "Curated model",
      curated.map((entry) => `${entry.name} (${entry.sourceId})`),
    );
    if (!picked) continue;
    const index = curated.findIndex(
      (entry) => `${entry.name} (${entry.sourceId})` === picked,
    );
    if (index === -1) continue;
    if (choice === "Remove model") {
      curated.splice(index, 1);
      continue;
    }
    const previous = curated[index];
    const base = catalog.find((model) => model.id === previous?.sourceId);
    if (!base) {
      ctx.ui.notify(
        "Model missing from catalog. Refresh before editing.",
        "warning",
      );
      continue;
    }
    const updated = await configureCuratedModel(ctx, base, previous);
    if (updated) curated[index] = updated;
  }
}

async function configureCuratedModel(
  ctx: ExtensionCommandContext,
  base: ProviderModelConfig,
  previous?: CuratedModel,
): Promise<CuratedModel | undefined> {
  const nameValue = await ctx.ui.input(
    `Canonical name for ${base.id}`,
    previous?.name ?? base.name,
  );
  if (nameValue === undefined) return undefined;
  let name = nameValue.trim();
  if (!name) name = base.name;
  const reasoning = await ctx.ui.confirm(
    "Thinking model?",
    `Register "${name}" with reasoning support?`,
  );
  return { sourceId: base.id, name, reasoning };
}

async function pickCatalogModel(
  ctx: ExtensionCommandContext,
  catalog: readonly ProviderModelConfig[],
  taken: ReadonlySet<string>,
): Promise<ProviderModelConfig | undefined> {
  while (true) {
    const filterValue = await ctx.ui.input(
      "Filter catalog by substring (empty = all)",
      "gpt",
    );
    if (filterValue === undefined) return undefined;
    const filter = filterValue.trim().toLowerCase();
    const candidates = catalog.filter(
      (model) =>
        !taken.has(model.id) &&
        (filter === "" ||
          model.id.toLowerCase().includes(filter) ||
          model.name.toLowerCase().includes(filter)),
    );
    if (candidates.length === 0) {
      ctx.ui.notify("No matching models.", "warning");
      continue;
    }
    const labels = candidates.map((model) => `${model.id} — ${model.name}`);
    const chosen = await ctx.ui.select(
      `Select model (${candidates.length} available)`,
      labels,
    );
    if (chosen === undefined) return undefined;
    return candidates.find((model) => `${model.id} — ${model.name}` === chosen);
  }
}

async function refreshProviders(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  id: string,
): Promise<void> {
  let targets = [...savedEndpoints()];
  if (id) targets = savedEndpoints().filter((entry) => entry.id === id);
  if (id && targets.length === 0) {
    ctx.ui.notify(`Provider ${id} is not saved.`, "warning");
    return;
  }
  if (targets.length === 0) {
    ctx.ui.notify("No custom providers.", "info");
    return;
  }
  let ok = 0;
  let failed = 0;
  for (const entry of targets) {
    try {
      const models = await refreshSaved(entry.id, true, ctx.signal);
      pi.registerProvider(entry.id, providerConfig(entry, models));
      ok += 1;
    } catch (error) {
      failed += 1;
      ctx.ui.notify(`${entry.id}: ${errorMessage(error)}`, "error");
    }
  }
  if (failed === 0) {
    ctx.ui.notify(`Refreshed ${ok} providers.`, "info");
    return;
  }
  ctx.ui.notify(`Refreshed ${ok}, failed ${failed}.`, "warning");
}

async function removeProvider(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  id: string,
): Promise<void> {
  if (!savedProvider(id)) {
    ctx.ui.notify(`Provider ${id} is not saved.`, "warning");
    return;
  }
  pi.unregisterProvider(id);
  await forgetProvider(id);
  ctx.ui.notify(
    `Removed ${id}. Log out separately if a key is stored.`,
    "info",
  );
}

function completions(prefix: string) {
  const trimmed = prefix.trimStart();
  const space = trimmed.indexOf(" ");
  if (space === -1) {
    return ACTIONS.filter((action) => action.startsWith(trimmed)).map(
      (value) => ({
        value,
        label: value,
      }),
    );
  }
  const action = trimmed.slice(0, space);
  if (action !== "refresh" && action !== "remove" && action !== "edit") {
    return [];
  }
  const idPrefix = trimmed.slice(space + 1);
  return savedEndpoints()
    .filter((entry) => entry.id.startsWith(idPrefix))
    .map((entry) => ({ value: `${action} ${entry.id}`, label: entry.id }));
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}
