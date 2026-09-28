import assert from "node:assert/strict";
import test from "node:test";
import { refreshCuratedProviders } from "./startup.ts";
import type { SavedProvider } from "./store.ts";

const providers: SavedProvider[] = [
  {
    id: "curated",
    name: "Curated",
    baseUrl: "https://curated.example/v1",
    models: [{ sourceId: "model-a", name: "Model A", reasoning: true }],
  },
  {
    id: "all-models",
    name: "All models",
    baseUrl: "https://all.example/v1",
  },
  {
    id: "unavailable",
    name: "Unavailable",
    baseUrl: "https://unavailable.example/v1",
    models: [{ sourceId: "model-b", name: "Model B", reasoning: false }],
  },
];

test("startup refresh targets curated providers and keeps failures visible", async () => {
  const refreshed: string[] = [];
  const failures = await refreshCuratedProviders(
    providers,
    async (provider) => {
      refreshed.push(provider.id);
      if (provider.id === "unavailable") throw new Error("offline");
    },
  );

  assert.deepEqual(refreshed.sort(), ["curated", "unavailable"]);
  assert.deepEqual(failures, [{ id: "unavailable", message: "offline" }]);
});
