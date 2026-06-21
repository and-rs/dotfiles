import { realpath, stat, readFile } from "node:fs/promises";
import { dirname, isAbsolute, relative, resolve } from "node:path";
import { MAX_TEXT_FILE_BYTES } from "./types.ts";


function normalizeToolPathInput(candidatePath: string): string {
  const trimmed = candidatePath.trim();
  return trimmed.startsWith("@") && trimmed.length > 1 ? trimmed.slice(1) : candidatePath;
}

function resolveToolPath(cwd: string, candidatePath: string): string {
  const normalized = normalizeToolPathInput(candidatePath);
  return isAbsolute(normalized) ? resolve(normalized) : resolve(cwd, normalized);
}

function isPathInRoot(root: string, candidatePath: string): boolean {
  const rel = relative(resolve(root), candidatePath);
  return rel === "" || (!rel.startsWith("..") && !isAbsolute(rel));
}

async function realpathIfExists(path: string): Promise<string | null> {
  try { return await realpath(path); } catch (error) { const nodeError = error as NodeJS.ErrnoException; if (nodeError.code === "ENOENT") return null; throw error; }
}

async function findExistingAncestor(path: string): Promise<string> {
  let current = dirname(path);
  while (true) {
    const resolved = await realpathIfExists(current);
    if (resolved) return resolved;
    const parent = dirname(current);
    if (parent === current) return current;
    current = parent;
  }
}

function assertPathInCwd(cwd: string, candidatePath: string, absolutePath: string): void {
  if (!isPathInRoot(cwd, absolutePath)) throw new Error(`Path outside cwd: ${candidatePath}. Start pi in target repo before editing or creating files. Current cwd: ${cwd}`);
}

export async function ensureExistingPathInCwd(cwd: string, candidatePath: string): Promise<string> {
  const absolute = resolveToolPath(cwd, candidatePath);
  assertPathInCwd(cwd, candidatePath, absolute);
  const resolved = await realpathIfExists(absolute);
  if (resolved) assertPathInCwd(cwd, candidatePath, resolved);
  return absolute;
}

export async function ensureCreatablePathInCwd(cwd: string, candidatePath: string): Promise<string> {
  const absolute = resolveToolPath(cwd, candidatePath);
  assertPathInCwd(cwd, candidatePath, absolute);
  const existing = await realpathIfExists(absolute);
  if (existing) assertPathInCwd(cwd, candidatePath, existing);
  const ancestor = await findExistingAncestor(absolute);
  assertPathInCwd(cwd, candidatePath, ancestor);
  return absolute;
}


function looksBinary(buffer: Buffer): boolean {
  const sampleLength = Math.min(buffer.length, 8192);
  for (let i = 0; i < sampleLength; i++) if (buffer[i] === 0) return true;
  return false;
}

export async function readTextFile(path: string): Promise<{ exists: boolean; text: string }> {
  try {
    const info = await stat(path);
    if (!info.isFile()) throw new Error(`Not a file: ${path}`);
    if (info.size > MAX_TEXT_FILE_BYTES) throw new Error(`File too large for hashline tools: ${path} (${info.size} bytes, max ${MAX_TEXT_FILE_BYTES})`);
    const buffer = await readFile(path);
    if (looksBinary(buffer)) throw new Error(`Binary file not supported by hashline tools: ${path}`);
    return { exists: true, text: buffer.toString("utf8") };
  } catch (error) {
    const nodeError = error as NodeJS.ErrnoException;
    if (nodeError.code === "ENOENT") return { exists: false, text: "" };
    throw error;
  }
}
