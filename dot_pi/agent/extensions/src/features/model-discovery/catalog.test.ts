import assert from "node:assert/strict";
import test from "node:test";
import type { ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import {
  baseCatalogConfigs,
  buildCuratedConfigs,
  mapCatalog,
} from "./catalog.ts";
import { providerIdError } from "./rules.ts";

test("mapCatalog keeps text models and drops other types", () => {
  const models = mapCatalog({
    data: [
      {
        id: "alpha",
        name: "Alpha",
        context_window: 32000,
        max_tokens: 2048,
      },
      { id: "picture", type: "image" },
      { type: "text" },
      { id: "plain" },
    ],
  });

  assert.deepEqual(
    models.map((model) => model.id),
    ["alpha", "plain"],
  );
  const alpha = models[0];
  assert.ok(alpha);
  assert.equal(alpha.name, "Alpha");
  assert.equal(alpha.contextWindow, 32000);
  assert.equal(alpha.maxTokens, 2048);
  assert.equal(alpha.reasoning, false);
  const compat = alpha.compat as
    | {
        supportsDeveloperRole?: boolean;
        supportsReasoningEffort?: boolean;
      }
    | undefined;
  assert.equal(compat?.supportsDeveloperRole, false);
  assert.equal(compat?.supportsReasoningEffort, false);
  const plain = models[1];
  assert.ok(plain);
  assert.equal(plain.contextWindow, 128000);
  assert.equal(plain.maxTokens, 16384);
  assert.deepEqual(plain.cost, {
    input: 0,
    output: 0,
    cacheRead: 0,
    cacheWrite: 0,
  });
});

test("providerIdError rejects occupied built-in ids", () => {
  const occupied = new Set(["xai"]);
  const owned = new Set<string>();

  assert.match(providerIdError("xai", occupied, owned) ?? "", /already exists/);
  assert.equal(providerIdError("custom-api", occupied, owned), undefined);
  assert.match(providerIdError("Bad Id", occupied, owned) ?? "", /lowercase/);
});

test("mapCatalog ignores provider-specific model metadata", () => {
  const model = mapCatalog({
    data: [
      {
        id: "custom-model",
        model_spec: {
          name: "Provider-specific name",
          availableContextTokens: 64000,
          capabilities: {
            supportsReasoning: true,
            supportsReasoningEffort: true,
            reasoningEffortOptions: ["none", "high"],
            supportsVision: true,
          },
        },
      },
    ],
  })[0];

  assert.ok(model);
  assert.equal(model.name, "custom-model");
  assert.equal(model.reasoning, false);
  assert.equal(model.contextWindow, 128000);
  assert.deepEqual(model.input, ["text"]);
  assert.equal(model.thinkingLevelMap, undefined);
  assert.deepEqual(model.compat, {
    supportsDeveloperRole: false,
    supportsReasoningEffort: false,
  });
});

test("baseCatalogConfigs strips cached provider-specific behavior", () => {
  const base = mapCatalog({
    data: [{ id: "cached", context_window: 64000 }],
  })[0];
  assert.ok(base);
  const cached = {
    ...base,
    reasoning: true,
    thinkingLevelMap: { off: "none", high: "high" },
    compat: {
      supportsDeveloperRole: true,
      supportsReasoningEffort: true,
      thinkingFormat: "together",
    },
    providerMetadata: { effort: "none" },
  } as ProviderModelConfig;

  const model = baseCatalogConfigs([cached])[0];

  assert.ok(model);
  assert.equal(model.reasoning, false);
  assert.equal(model.thinkingLevelMap, undefined);
  assert.deepEqual(model.input, ["text"]);
  assert.deepEqual(model.compat, {
    supportsDeveloperRole: false,
    supportsReasoningEffort: false,
  });
  assert.equal("providerMetadata" in model, false);
});

test("buildCuratedConfigs joins curated entries with catalog metadata", () => {
  const catalog = mapCatalog({
    data: [
      { id: "gpt-5-2025", name: "GPT-5 2025", context_window: 400000 },
      { id: "dolphin", name: "Dolphin" },
    ],
  });

  const result = buildCuratedConfigs(catalog, [
    { sourceId: "gpt-5-2025", name: "GPT-5 High", reasoning: true },
    { sourceId: "dolphin", name: "Dolphin Fast", reasoning: false },
    { sourceId: "ghost", name: "Ghost", reasoning: true },
  ]);

  assert.deepEqual(result.missing, ["ghost"]);
  assert.equal(result.configs.length, 2);
  const thinking = result.configs[0];
  assert.ok(thinking);
  assert.equal(thinking.name, "GPT-5 High");
  assert.equal(thinking.reasoning, true);
  assert.equal(thinking.contextWindow, 400000);
  const compat = thinking.compat as
    | {
        supportsDeveloperRole?: boolean;
        supportsReasoningEffort?: boolean;
      }
    | undefined;
  assert.equal(compat?.supportsReasoningEffort, true);
  const plain = result.configs[1];
  assert.ok(plain);
  assert.equal(plain.reasoning, false);
  const plainCompat = plain.compat as
    | {
        supportsReasoningEffort?: boolean;
      }
    | undefined;
  assert.equal(plainCompat?.supportsReasoningEffort, false);
});
