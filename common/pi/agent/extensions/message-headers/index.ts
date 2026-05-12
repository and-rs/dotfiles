import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const AUTH_PATH = join(homedir(), ".pi", "agent", "auth.json");
const ADMIN_BASE = "https://admin-api.exa.ai/team-management";

type AuthRecord = Record<string, unknown>;

type ApiKeyEntry = {
  type?: string;
  key?: string;
};

type ListApiKeysResponse = {
  apiKeys?: Array<{
    id: string;
    budgetCents?: number | null;
    isOverBudget?: boolean;
  }>;
};

type UsageResponse = {
  total_cost_usd?: number;
};

async function readAuthFile(): Promise<AuthRecord> {
  try {
    const raw = await readFile(AUTH_PATH, "utf8");
    const parsed = JSON.parse(raw) as unknown;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return {};
    }
    return parsed as AuthRecord;
  } catch {
    return {};
  }
}

async function resolveStoredKeyValue(value: string): Promise<string> {
  const trimmed = value.trim();
  if (!trimmed) {
    return "";
  }

  if (/^[A-Z][A-Z0-9_]*$/.test(trimmed) && process.env[trimmed]) {
    return process.env[trimmed]?.trim() ?? "";
  }

  return trimmed;
}

async function resolveExaApiKey(): Promise<string | null> {
  const auth = await readAuthFile();
  const entry = auth.exa as ApiKeyEntry | undefined;

  if (entry?.type === "api_key" && typeof entry.key === "string") {
    const resolved = await resolveStoredKeyValue(entry.key);
    if (resolved) {
      return resolved;
    }
  }

  const envKey = process.env.EXA_API_KEY?.trim();
  return envKey || null;
}

function isoDaysAgo(days: number): string {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
}

function fmtUsd(value: number): string {
  return `$${value.toFixed(2)}`;
}

async function fetchJson<T>(url: string, apiKey: string): Promise<T> {
  const res = await fetch(url, {
    method: "GET",
    headers: {
      "x-api-key": apiKey,
      accept: "application/json",
    },
  });

  if (!res.ok) {
    throw new Error(`HTTP ${res.status}`);
  }

  return (await res.json()) as T;
}

async function computeExaUsageSummary(apiKey: string): Promise<string> {
  const list = await fetchJson<ListApiKeysResponse>(`${ADMIN_BASE}/api-keys`, apiKey);
  const apiKeys = Array.isArray(list.apiKeys) ? list.apiKeys : [];

  if (apiKeys.length === 0) {
    return "EXA no-api-keys";
  }

  const startDate = encodeURIComponent(isoDaysAgo(30));
  const totals = await Promise.all(
    apiKeys.map(async (item) => {
      const usage = await fetchJson<UsageResponse>(
        `${ADMIN_BASE}/api-keys/${item.id}/usage?start_date=${startDate}`,
        apiKey,
      );
      return typeof usage.total_cost_usd === "number" ? usage.total_cost_usd : 0;
    }),
  );

  const totalUsd = totals.reduce((acc, value) => acc + value, 0);
  const budgetCents = apiKeys.reduce((acc, item) => acc + (typeof item.budgetCents === "number" ? item.budgetCents : 0), 0);
  const anyBudget = apiKeys.some((item) => typeof item.budgetCents === "number");
  const anyOver = apiKeys.some((item) => item.isOverBudget === true);

  if (!anyBudget) {
    return `EXA 30d ${fmtUsd(totalUsd)}`;
  }

  const budgetUsd = budgetCents / 100;
  const remaining = budgetUsd - totalUsd;
  const status = anyOver || remaining < 0 ? "over" : "left";
  return `EXA 30d ${fmtUsd(totalUsd)} ${status} ${fmtUsd(Math.abs(remaining))}`;
}

export default function messageHeadersExtension(pi: ExtensionAPI) {
  let line = "EXA ...";
  let refreshInFlight = false;
  let setStatusLine: ((value: string) => void) | null = null;

  const refresh = async () => {
    if (refreshInFlight) {
      return;
    }

    refreshInFlight = true;
    try {
      const key = await resolveExaApiKey();
      if (!key) {
        line = "EXA no-key";
      } else {
        line = await computeExaUsageSummary(key);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : "";
      if (message.includes("HTTP 401") || message.includes("HTTP 403")) {
        line = "EXA service-key-required";
      } else {
        line = "EXA usage-unavailable";
      }
    } finally {
      refreshInFlight = false;
      setStatusLine?.(line);
    }
  };

  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) {
      return;
    }

    setStatusLine = (value: string) => {
      ctx.ui.setStatus("exa-credits", ctx.ui.theme.fg("dim", value));
    };

    setStatusLine(line);
    void refresh();
  });

  pi.on("tool_execution_end", async (event) => {
    if (event.toolName !== "exa_search") {
      return;
    }
    await refresh();
  });

  pi.on("session_shutdown", (_event, ctx) => {
    ctx.ui.setStatus("exa-credits", undefined);
    setStatusLine = null;
  });

  pi.registerCommand("exa_usage", {
    description: "Refresh Exa usage indicator",
    handler: async (_args, ctx) => {
      setStatusLine = (value: string) => {
        ctx.ui.setStatus("exa-credits", ctx.ui.theme.fg("dim", value));
      };
      await refresh();
      ctx.ui.notify(line, "info");
    },
  });
}
