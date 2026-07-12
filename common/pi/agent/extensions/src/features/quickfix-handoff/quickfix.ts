import { loadCodeFile, type CodeFile } from "../code-view/read.ts";

const MAX_LOCATIONS = 50;

export interface QuickfixLocationInput {
  path: string;
  line: number;
  column?: number;
  reason: string;
}

interface VerifiedQuickfixLocation {
  path: string;
  line: number;
  column: number;
  reason: string;
}

export interface QuickfixHandoff {
  locations: VerifiedQuickfixLocation[];
  script: string;
}


function quoteNushell(value: string): string {
  return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

function validateLocation(input: QuickfixLocationInput): void {
  if (!input.reason.trim()) throw new Error(`Quickfix reason is required for ${input.path}:${input.line}.`);
  if (/\r|\n/.test(input.reason)) throw new Error(`Quickfix reason must be one line: ${input.path}:${input.line}.`);
}

async function getCodeFile(
  cwd: string,
  requestedPath: string,
  cache: Map<string, Promise<CodeFile>>,
): Promise<CodeFile> {
  let file = cache.get(requestedPath);
  if (!file) {
    file = loadCodeFile(cwd, requestedPath);
    cache.set(requestedPath, file);
  }
  return file;
}

export async function createQuickfixHandoff(
  cwd: string,
  inputs: QuickfixLocationInput[],
): Promise<QuickfixHandoff> {
  if (!inputs.length) throw new Error("At least one quickfix location is required.");
  if (inputs.length > MAX_LOCATIONS) throw new Error(`Quickfix handoff supports at most ${MAX_LOCATIONS} locations.`);

  const cache = new Map<string, Promise<CodeFile>>();
  const locations: VerifiedQuickfixLocation[] = [];
  for (const input of inputs) {
    validateLocation(input);
    const file = await getCodeFile(cwd, input.path, cache);
    if (input.line > file.totalLines) {
      throw new Error(`Line ${input.line} exceeds file length ${file.totalLines}: ${input.path}`);
    }
    locations.push({
      path: file.absolutePath,
      line: input.line,
      column: input.column ?? 1,
      reason: input.reason.trim(),
    });
  }

  const entries = locations.map((location) =>
    quoteNushell(`${location.path}:${location.line}:${location.column}:${location.reason}`),
  );
  const script = [
    "[",
    ...entries.map((entry, index) => `  ${entry}${index === entries.length - 1 ? "" : ","}`),
    "] | str join (char nl) | nvim -q -",
  ].join("\n");

  return { locations, script };
}
