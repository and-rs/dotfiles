import { readFile, realpath, stat } from "node:fs/promises";
import path from "node:path";

const MAX_FILE_BYTES = 2 * 1024 * 1024;
const DEFAULT_LINE_COUNT = 400;
const MAX_LINE_COUNT = 1_000;

export interface CodeViewLine {
  number: number;
  text: string;
}

export interface CodeViewResult {
  path: string;
  startLine: number;
  endLine: number;
  totalLines: number;
  hasMoreLines: boolean;
  lines: CodeViewLine[];
}

export interface CodeFile {
  path: string;
  absolutePath: string;
  totalLines: number;
  lines: string[];
}

function isInside(root: string, target: string): boolean {
  const relative = path.relative(root, target);
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative));
}

function splitLines(source: string): string[] {
  const lines = source.split(/\r\n|\n|\r/);
  if (source.endsWith("\n") || source.endsWith("\r")) lines.pop();
  return lines;
}

export async function loadCodeFile(
  cwd: string,
  requestedPath: string,
): Promise<CodeFile> {

  const root = await realpath(cwd);
  const candidate = path.resolve(root, requestedPath);
  if (!isInside(root, candidate)) throw new Error(`Path must be inside cwd: ${requestedPath}`);

  const target = await realpath(candidate);
  if (!isInside(root, target)) throw new Error(`Path resolves outside cwd: ${requestedPath}`);

  const file = await stat(target);
  if (!file.isFile()) throw new Error(`Not a file: ${requestedPath}`);
  if (file.size > MAX_FILE_BYTES) {
    throw new Error(`File is too large to view: ${requestedPath}`);
  }

  const buffer = await readFile(target);
  if (buffer.includes(0)) throw new Error(`Binary file cannot be viewed: ${requestedPath}`);

  const source = buffer.toString("utf8");
  const allLines = splitLines(source);
  const totalLines = allLines.length;


  return {
    path: path.relative(root, target) || path.basename(target),
    absolutePath: target,
    totalLines,
    lines: allLines,
  };
}

export async function readCodeView(
  cwd: string,
  requestedPath: string,
  startLine = 1,
  endLine?: number,
): Promise<CodeViewResult> {
  if (endLine !== undefined && endLine < startLine) {
    throw new Error("end must be greater than or equal to start.");
  }
  if (endLine !== undefined && endLine - startLine + 1 > MAX_LINE_COUNT) {
    throw new Error(`Requested range exceeds ${MAX_LINE_COUNT} lines. Read a smaller range.`);
  }

  const file = await loadCodeFile(cwd, requestedPath);
  if (startLine > file.totalLines) {
    throw new Error(`Start line ${startLine} exceeds file length ${file.totalLines}: ${requestedPath}`);
  }

  const requestedEnd = endLine ?? startLine + DEFAULT_LINE_COUNT - 1;
  const actualEnd = Math.min(requestedEnd, file.totalLines);
  const lines = file.lines.slice(startLine - 1, actualEnd).map((text, index) => ({
    number: startLine + index,
    text,
  }));

  return {
    path: file.path,
    startLine,
    endLine: actualEnd,
    totalLines: file.totalLines,
    hasMoreLines: endLine === undefined && actualEnd < file.totalLines,
    lines,
  };
}

export function formatCodeView(result: CodeViewResult): string {
  const range = `${result.startLine}-${result.endLine} of ${result.totalLines}`;
  const more = result.hasMoreLines ? " · more lines available" : "";
  const width = String(result.endLine).length;
  const lines = result.lines.map(({ number, text }) => `${String(number).padStart(width)}: ${text}`);
  return [`code-view ${result.path} · lines ${range}${more}`, ...lines].join("\n");
}
