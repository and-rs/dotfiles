import { exec as execCallback } from "node:child_process";
import { chmod, mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { promisify } from "node:util";

const exec = promisify(execCallback);

export const AUTH_PATH = join(homedir(), ".pi", "agent", "auth.json");

export type AuthRecord = Record<string, unknown>;

export type ApiKeyEntry = {
  type?: string;
  key?: string;
};

export type ExaKeyKind = "api" | "service";

export type ResolvedExaKey = {
  key: string | null;
  source: "auth" | "env" | null;
};

const AUTH_KEYS: Record<ExaKeyKind, string> = {
  api: "exa",
  service: "exa_service",
};

const ENV_KEYS: Record<ExaKeyKind, string> = {
  api: "EXA_API_KEY",
  service: "EXA_SERVICE_KEY",
};

export async function readAuthFile(): Promise<AuthRecord> {
  try {
    const raw = await readFile(AUTH_PATH, "utf8");
    const parsed = JSON.parse(raw) as unknown;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("auth.json must contain an object");
    }
    return parsed as AuthRecord;
  } catch (error) {
    const nodeError = error as NodeJS.ErrnoException;
    if (nodeError.code === "ENOENT") {
      return {};
    }
    throw error;
  }
}

export async function writeAuthFile(data: AuthRecord): Promise<void> {
  await mkdir(dirname(AUTH_PATH), { recursive: true, mode: 0o700 });
  await writeFile(AUTH_PATH, `${JSON.stringify(data, null, 2)}\n`, { mode: 0o600 });
  await chmod(AUTH_PATH, 0o600);
}

export async function resolveStoredKeyValue(value: string): Promise<string> {
  const trimmed = value.trim();
  if (!trimmed) {
    return "";
  }

  if (trimmed.startsWith("!")) {
    const command = trimmed.slice(1).trim();
    if (!command) {
      return "";
    }
    const { stdout } = await exec(command, { shell: "/bin/sh" });
    return stdout.trim();
  }

  if (/^[A-Z][A-Z0-9_]*$/.test(trimmed) && process.env[trimmed]) {
    return process.env[trimmed]?.trim() ?? "";
  }

  return trimmed;
}

export async function getStoredExaEntry(kind: ExaKeyKind): Promise<ApiKeyEntry | null> {
  const auth = await readAuthFile();
  const entry = auth[AUTH_KEYS[kind]] as ApiKeyEntry | undefined;
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
    return null;
  }
  return entry;
}

export async function resolveExaKey(kind: ExaKeyKind): Promise<ResolvedExaKey> {
  const stored = await getStoredExaEntry(kind);
  if (stored?.type === "api_key" && typeof stored.key === "string") {
    const resolved = await resolveStoredKeyValue(stored.key);
    if (resolved) {
      return { key: resolved, source: "auth" };
    }
  }

  const envKey = process.env[ENV_KEYS[kind]]?.trim();
  if (envKey) {
    return { key: envKey, source: "env" };
  }

  return { key: null, source: null };
}


export async function saveExaKey(kind: ExaKeyKind, key: string): Promise<void> {
  const auth = await readAuthFile();
  auth[AUTH_KEYS[kind]] = { type: "api_key", key: key.trim() };
  await writeAuthFile(auth);
}

export async function clearExaKey(kind: ExaKeyKind): Promise<boolean> {
  const auth = await readAuthFile();
  if (!(AUTH_KEYS[kind] in auth)) {
    return false;
  }
  delete auth[AUTH_KEYS[kind]];
  await writeAuthFile(auth);
  return true;
}

export function formatExaSource(kind: ExaKeyKind, source: "auth" | "env"): string {
  return source === "auth" ? AUTH_PATH : `${ENV_KEYS[kind]} env`;
}
