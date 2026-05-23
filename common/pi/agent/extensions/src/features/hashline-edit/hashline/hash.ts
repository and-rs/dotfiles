/** Core hash utilities for hashline anchors and read output. */

import XXH from "xxhashjs";
import bigrams from "./bigrams.json" with { type: "json" };

/**
 * 647 single-token BPE bigrams for hashline anchors. Every entry tokenizes as
 * exactly one token in modern BPE vocabularies (cl100k / o200k / Claude family),
 * so a hashline anchor built from one bigram is exactly 1 token.
 *
 * This is the complete set of 2-letter lowercase combinations that are single
 * tokens — the 29 missing combinations are rare-letter pairs (q/x/z heavy)
 * that no major BPE vocabulary merges into a single token.
 *
 * Order is stable forever — changing it would invalidate every saved
 * `LINE+ID` reference in transcripts and prompts.
 */
export const HL_BIGRAMS: readonly string[] = bigrams;

export const HL_BIGRAMS_COUNT = HL_BIGRAMS.length;

/**
 * Decoration prefix that may precede a `LINE+HASH` anchor in tool output:
 * `>` (context line in grep), `+` (added line in diff), `-` (removed line),
 * `*` (match line). Any combination, in any order, surrounded by optional
 * whitespace. Output formatters emit at most one decoration per anchor; the
 * regex stays liberal because anchor-ref parsers accept whatever the model
 * echoes back.
 */
export const HL_ANCHOR_DECORATION_RE_RAW = `\\s*[>+\\-*]*\\s*`;

/**
 * Capture-group regex source for a decorated `LINE+HASH` anchor. Group 1
 * captures the line number (digits only); group 2 captures the hash. The
 * source is intentionally unanchored — anchoring with `^` (or composing into a
 * larger pattern) is the caller's responsibility.
 */
export const HL_ANCHOR_RE_RAW = `${HL_ANCHOR_DECORATION_RE_RAW}(\\d+)([a-z]{2})`;


/**
 * Representative hash suffixes for use in user-facing error messages and
 * prompt examples.
 */
export const HL_HASH_EXAMPLES = ["sr", "ab", "th"] as const;

/**
 * Format a comma-separated list of example anchors with an optional line-number
 * prefix, quoted for inclusion in error messages: `"160sr", "160ab", "160th"`.
 */
export function describeAnchorExamples(linePrefix = ""): string {
	return HL_HASH_EXAMPLES.map(e => `"${linePrefix}${e}"`).join(", ");
}


/** Stable separator for read/search/hashline display output. Intentionally not configurable. */
export const HL_BODY_SEP = "|";


const RE_SIGNIFICANT = /[\p{L}\p{N}]/u;

/**
 * Compute a 2-character hash of a single line via xxHash32 mod 647 over
 * {@link HL_BIGRAMS}. Lines with no letter or digit mix the line number
 * into the seed so adjacent identical punctuation-only lines (e.g. brace-only
 * lines) get distinct hashes; lines with significant content stay
 * line-number-independent so a line is identifiable across small shifts.
 *
 * The line input should not include a trailing newline.
 */
export function computeLineHash(idx: number, line: string): string {
	line = line.replace(/\r/g, "").trimEnd();
	const seed = RE_SIGNIFICANT.test(line) ? 0 : idx;
	return HL_BIGRAMS[XXH.h32(line, seed).toNumber() % HL_BIGRAMS_COUNT];
}

/**
 * Formats an anchor reference given a line number and its text.
 * Returns `LINE+ID` (e.g., `42sr`) — no separator between
 * number and hash.
 */
export function formatLineHash(line: number, lines: string): string {
	return `${line}${computeLineHash(line, lines)}`;
}

/**
 * Formats a single line with a hashline anchor.
 * Returns `LINE+ID|TEXT` (e.g., `42sr|function hi() {`, `3ab|}`).
 */
export function formatHashLine(lineNumber: number, line: string): string {
	return `${lineNumber}${computeLineHash(lineNumber, line)}${HL_BODY_SEP}${line}`;
}

/**
 * Format file text with hashline prefixes for display.
 *
 * Each line becomes `LINE+ID|TEXT` where LINENUM is 1-indexed.
 * No padding on line numbers; pipe separator between anchor and content.
 *
 * @param text - Raw file text string
 * @param startLine - First line number (1-indexed, defaults to 1)
 * @returns Formatted string with one hashline-prefixed line per input line
 *
 * @example
 * ```
 * formatHashLines("function hi() {\n  return;\n}")
 * // "1bm|function hi() {\n2er|  return;\n3ab|}"
 * ```
 */
export function formatHashLines(text: string, startLine = 1): string {
	const lines = text.split("\n");
	return lines.map((line, i) => formatHashLine(startLine + i, line)).join("\n");
}
