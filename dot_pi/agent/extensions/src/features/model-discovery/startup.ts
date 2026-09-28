import type { SavedProvider } from "./store.ts";

export type StartupRefreshFailure = {
  id: string;
  message: string;
};

export async function refreshCuratedProviders(
  providers: readonly SavedProvider[],
  refresh: (provider: SavedProvider) => Promise<void>,
): Promise<StartupRefreshFailure[]> {
  const failures: StartupRefreshFailure[] = [];
  const curated = providers.filter(
    (provider) => (provider.models?.length ?? 0) > 0,
  );
  await Promise.all(
    curated.map(async (provider) => {
      try {
        await refresh(provider);
      } catch (error) {
        failures.push({ id: provider.id, message: errorMessage(error) });
      }
    }),
  );
  return failures;
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}
