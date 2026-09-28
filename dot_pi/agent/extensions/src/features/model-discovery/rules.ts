const PROVIDER_ID = /^[a-z0-9][a-z0-9._-]{0,63}$/;

export function providerIdError(
  id: string,
  occupied: ReadonlySet<string>,
  owned: ReadonlySet<string>,
): string | undefined {
  if (!PROVIDER_ID.test(id)) {
    return "Provider id must be 1-64 characters of lowercase letters, numbers, dots, underscores, or hyphens.";
  }
  if (owned.has(id)) return `Provider ${id} is already saved.`;
  if (occupied.has(id)) return `Provider ${id} already exists.`;
  return undefined;
}

export function occupiedProviderIds(
  models: readonly { provider: string }[],
): Set<string> {
  const ids = new Set<string>();
  for (const model of models) ids.add(model.provider);
  return ids;
}
