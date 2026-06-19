import XXH from "xxhashjs";
import bigrams from "./bigrams.json" with { type: "json" };

export const HL_BIGRAMS: readonly string[] = bigrams;
export const HL_BIGRAMS_COUNT = HL_BIGRAMS.length;
export const HL_BODY_SEP = "|";

const RE_SIGNIFICANT = /[\p{L}\p{N}]/u;

export function computeLineHash(idx: number, line: string): string {
	line = line.replace(/\r/g, "").trimEnd();
	const seed = RE_SIGNIFICANT.test(line) ? 0 : idx;
	return HL_BIGRAMS[XXH.h32(line, seed).toNumber() % HL_BIGRAMS_COUNT];
}

export function formatHashLine(lineNumber: number, line: string): string {
	return `${lineNumber}${computeLineHash(lineNumber, line)}${HL_BODY_SEP}${line}`;
}

export function formatHashLines(text: string, startLine = 1): string {
	const lines = text.split("\n");
	return lines.map((line, i) => formatHashLine(startLine + i, line)).join("\n");
}
