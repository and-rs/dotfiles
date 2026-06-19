import { formatHashLines } from "./hashline/index.ts";
import { AUTO_FULL_FILE_LINES } from "./types.ts";

export type SegmentOption = {
  label: string;
  startLine: number;
  endLine: number;
  lineCount: number;
  preview: string;
};

export type HashlineContextRange = {
  kind: "range";
  path: string;
  startLine: number;
  endLine: number;
  totalLines: number;
  segment?: string;
  body: string;
};

export type HashlineContextMap = {
  kind: "map";
  path: string;
  totalLines: number;
  segment?: string;
  options: SegmentOption[];
  body: string;
};

export type HashlineContextResult = HashlineContextRange | HashlineContextMap;

function previewSegmentLine(line: string): string {
  const compact = line.trim().replace(/\s+/g, " ");
  if (!compact) return "(blank)";
  return compact.length <= 80 ? compact : `${compact.slice(0, 79)}…`;
}

function midpoint(startLine: number, endLine: number): number {
  return Math.floor((startLine + endLine) / 2);
}

function splitSegment(label: string, startLine: number, endLine: number): SegmentOption[] {
  if (startLine >= endLine) {
    return [{ label, startLine, endLine, lineCount: endLine - startLine + 1, preview: "single line" }];
  }
  const mid = midpoint(startLine, endLine);
  return [
    { label: `${label}A`, startLine, endLine: mid, lineCount: mid - startLine + 1, preview: "" },
    { label: `${label}B`, startLine: mid + 1, endLine, lineCount: endLine - mid, preview: "" },
  ];
}

export function resolveSegment(totalLines: number, segment: string): { startLine: number; endLine: number } {
  let startLine = 1;
  let endLine = totalLines;
  for (const step of segment) {
    if (step !== "A" && step !== "B") throw new Error(`Invalid segment: ${segment}. Use labels like A, B, AA, or AB.`);
    if (startLine >= endLine) break;
    const mid = midpoint(startLine, endLine);
    if (step === "A") endLine = mid;
    else startLine = mid + 1;
  }
  return { startLine, endLine };
}

function buildSegmentOptions(lines: string[], startLine: number, endLine: number, baseLabel = ""): SegmentOption[] {
  return splitSegment(baseLabel, startLine, endLine).map((option) => {
    const first = previewSegmentLine(lines[option.startLine - 1] ?? "");
    const last = previewSegmentLine(lines[option.endLine - 1] ?? "");
    const preview = option.startLine === option.endLine ? first : `${first} … ${last}`;
    return { ...option, preview };
  });
}

function formatSegmentMap(path: string, totalLines: number, options: SegmentOption[], segment?: string): string {
  const title = segment ? `segment ${segment}` : "file";
  return [
    `${path}: ${totalLines} lines`,
    `${title} too large for whole-file context`,
    "choose segment:",
    ...options.map((option) => `- ${option.label}: lines ${option.startLine}-${option.endLine} (${option.lineCount} lines) :: ${option.preview}`),
    "call hashline-edit again with same path and chosen segment label",
    "follow staged hashline-edit flow using fresh live segment context",
  ].join("\n");
}

export function formatAnchoredSnippet(fileLines: string[], startLine: number, endLine: number): string {
  return formatHashLines(fileLines.slice(startLine - 1, endLine).join("\n"), startLine);
}

export function buildHashlineContext(path: string, normalized: string, segment?: string): HashlineContextResult {
  const allLines = normalized.split("\n");
  const totalLines = allLines.length;
  const target = segment ? resolveSegment(totalLines, segment) : { startLine: 1, endLine: totalLines };
  const targetLineCount = target.endLine - target.startLine + 1;
  if (targetLineCount <= AUTO_FULL_FILE_LINES) {
    const body = formatAnchoredSnippet(allLines, target.startLine, target.endLine);
    return {
      kind: "range",
      path,
      startLine: target.startLine,
      endLine: target.endLine,
      totalLines,
      segment,
      body,
    };
  }
  const options = buildSegmentOptions(allLines, target.startLine, target.endLine, segment ?? "");
  return {
    kind: "map",
    path,
    totalLines,
    segment,
    options,
    body: formatSegmentMap(path, totalLines, options, segment),
  };
}
