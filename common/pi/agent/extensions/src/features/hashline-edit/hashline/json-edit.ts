import { buildHashlineContext, formatAnchoredSnippet } from "../context.ts";

export type HashlineStageParams = {
	path: string;
	goal: string;
};

export type HashlineSegmentParams = {
	path: string;
	segment: string;
};

export type HashlineApplyParams = {
	path: string;
	edits: HashlineJsonEdit[];
};

export type HashlineToolParams =
	| HashlineStageParams
	| HashlineSegmentParams
	| HashlineApplyParams;

export type HashlineJsonEdit =
	| { op: "replace"; match: string[]; lines: string[] }
	| { op: "delete"; match: string[] }
	| { op: "insert_before"; match: string[]; lines: string[] }
	| { op: "insert_after"; match: string[]; lines: string[] };

export type HashlineJsonApplyResult = {
	lines: string;
	changed: boolean;
};

type MatchRange = {
	startLine: number;
	endLine: number;
};

type ResolvedJsonEdit =
	| { op: "replace"; index: number; startLine: number; endLine: number; lines: string[]; sourceIndex: number }
	| { op: "delete"; index: number; startLine: number; endLine: number; sourceIndex: number }
	| { op: "insert"; index: number; line: number; lines: string[]; sourceIndex: number };

type JsonRecord = Record<string, unknown>;

const STAGE_KEYS = new Set(["path", "goal"]);
const SEGMENT_KEYS = new Set(["path", "segment"]);
const APPLY_KEYS = new Set(["path", "edits"]);
const REPLACE_KEYS = new Set(["op", "match", "lines"]);
const DELETE_KEYS = new Set(["op", "match"]);
const INSERT_KEYS = new Set(["op", "match", "lines"]);

function isRecord(value: unknown): value is JsonRecord {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function rejectUnknownKeys(value: JsonRecord, allowed: Set<string>, loc: string): void {
	const unknown = Object.keys(value).filter((key) => !allowed.has(key));
	if (unknown.length > 0) {
		throw new Error(`schema_invalid: ${loc} contains unknown field(s): ${unknown.join(", ")}`);
	}
}

function requireString(value: JsonRecord, key: string, loc: string): string {
	const raw = value[key];
	if (typeof raw !== "string" || raw.trim().length === 0) {
		throw new Error(`schema_invalid: ${loc}.${key} must be a non-empty string.`);
	}
	return raw;
}

function requireTrimmedString(value: JsonRecord, key: string, loc: string): string {
	return requireString(value, key, loc).trim();
}

function requireLines(value: JsonRecord, key: string, loc: string): string[] {
	const raw = value[key];
	if (!Array.isArray(raw) || raw.length === 0) {
		throw new Error(`schema_invalid: ${loc}.${key} must be a non-empty string array.`);
	}
	return raw.map((line, index) => {
		if (typeof line !== "string") throw new Error(`schema_invalid: ${loc}.${key}[${index}] must be a string.`);
		if (line.includes("\n") || line.includes("\r")) {
			throw new Error(`schema_invalid: ${loc}.${key}[${index}] must be one logical line; newline characters are not allowed inside line strings.`);
		}
		return line;
	});
}

function parseJsonEdit(value: unknown, index: number): HashlineJsonEdit {
	const loc = `edits[${index}]`;
	if (!isRecord(value)) throw new Error(`schema_invalid: ${loc} must be an object.`);
	const op = requireString(value, "op", loc);
	if (op === "replace") {
		rejectUnknownKeys(value, REPLACE_KEYS, loc);
		return { op, match: requireLines(value, "match", loc), lines: requireLines(value, "lines", loc) };
	}
	if (op === "delete") {
		rejectUnknownKeys(value, DELETE_KEYS, loc);
		return { op, match: requireLines(value, "match", loc) };
	}
	if (op === "insert_before" || op === "insert_after") {
		rejectUnknownKeys(value, INSERT_KEYS, loc);
		return { op, match: requireLines(value, "match", loc), lines: requireLines(value, "lines", loc) };
	}
	throw new Error(`schema_invalid: ${loc}.op must be one of replace, delete, insert_before, insert_after.`);
}

function parseApplyParams(value: JsonRecord): HashlineApplyParams {
	rejectUnknownKeys(value, APPLY_KEYS, "params");
	const rawEdits = value.edits;
	if (!Array.isArray(rawEdits) || rawEdits.length === 0) {
		throw new Error("schema_invalid: params.edits must be a non-empty array.");
	}
	if (rawEdits.length > 8) {
		throw new Error("schema_invalid: params.edits may contain at most 8 edits. Split large edits into separate hashline-edit calls.");
	}
	return {
		path: requireString(value, "path", "params"),
		edits: rawEdits.map(parseJsonEdit),
	};
}

export function parseHashlineToolParams(value: unknown): HashlineToolParams {
	if (!isRecord(value)) throw new Error("schema_invalid: hashline-edit parameters must be an object.");
	if (value.edits !== undefined) return parseApplyParams(value);
	if (value.segment !== undefined) {
		rejectUnknownKeys(value, SEGMENT_KEYS, "params");
		return {
			path: requireString(value, "path", "params"),
			segment: requireTrimmedString(value, "segment", "params").toUpperCase(),
		};
	}
	if (value.goal !== undefined) {
		rejectUnknownKeys(value, STAGE_KEYS, "params");
		return {
			path: requireString(value, "path", "params"),
			goal: requireTrimmedString(value, "goal", "params"),
		};
	}
	throw new Error('schema_invalid: params must include exactly one of goal, segment, or edits.');
}

function formatFreshContext(fileLines: string[], centerLine: number, radius = 3): string {
	const start = Math.max(1, centerLine - radius);
	const end = Math.min(fileLines.length, centerLine + radius);
	return formatAnchoredSnippet(fileLines, start, end);
}

function collectRelatedLineNumbers(fileLines: string[], matchLines: string[]): number[] {
	const wanted = new Set(matchLines.filter((line) => line.trim().length > 0));
	const found: number[] = [];
	for (let index = 0; index < fileLines.length; index++) {
		if (!wanted.has(fileLines[index])) continue;
		found.push(index + 1);
		if (found.length >= 4) break;
	}
	return found;
}

function formatLiveFallback(path: string, fileLines: string[], matchLines: string[]): string {
	const related = collectRelatedLineNumbers(fileLines, matchLines);
	if (related.length > 0) {
		return [
			"Related live snippets:",
			"",
			...related.flatMap((line, index) => [
				`candidate ${index + 1}:`,
				formatFreshContext(fileLines, line),
				"",
			]),
		].join("\n").trimEnd();
	}
	const live = buildHashlineContext(path, fileLines.join("\n"));
	return [live.kind === "range" ? "Live file context:" : "Live file context map:", "", live.body].join("\n");
}

function formatMatchMissingError(path: string, fileLines: string[], editIndex: number, matchLines: string[]): string {
	return [
		"hashline-edit rejected: match_missing",
		"No changes were applied.",
		`path: ${path}`,
		`edits[${editIndex}].match: exact block not found in current file.`,
		"Use exact current file lines in match and retry.",
		"",
		formatLiveFallback(path, fileLines, matchLines),
	].join("\n");
}

function formatCandidateContext(fileLines: string[], range: MatchRange): string {
	const start = Math.max(1, range.startLine - 2);
	const end = Math.min(fileLines.length, range.endLine + 2);
	return formatAnchoredSnippet(fileLines, start, end);
}

function formatMatchAmbiguousError(path: string, fileLines: string[], editIndex: number, ranges: MatchRange[]): string {
	const shown = ranges.slice(0, 4);
	return [
		"hashline-edit rejected: match_ambiguous",
		"No changes were applied.",
		`path: ${path}`,
		`edits[${editIndex}].match: exact block resolved to ${ranges.length} locations in current file.`,
		"Use larger unique live match block and retry.",
		"",
		...shown.flatMap((range, index) => [
			`candidate ${index + 1}: lines ${range.startLine}-${range.endLine}`,
			formatCandidateContext(fileLines, range),
			"",
		]),
		...(ranges.length > shown.length ? [`... ${ranges.length - shown.length} more candidate(s) omitted`] : []),
	].join("\n").trimEnd();
}

function findBlockMatches(fileLines: string[], matchLines: string[]): MatchRange[] {
	if (matchLines.length > fileLines.length) return [];
	const matches: MatchRange[] = [];
	const lastStart = fileLines.length - matchLines.length;
	for (let start = 0; start <= lastStart; start++) {
		let equal = true;
		for (let offset = 0; offset < matchLines.length; offset++) {
			if (fileLines[start + offset] !== matchLines[offset]) {
				equal = false;
				break;
			}
		}
		if (equal) matches.push({ startLine: start + 1, endLine: start + matchLines.length });
	}
	return matches;
}

function resolveMatch(path: string, fileLines: string[], matchLines: string[], sourceIndex: number): MatchRange {
	const matches = findBlockMatches(fileLines, matchLines);
	if (matches.length === 0) throw new Error(formatMatchMissingError(path, fileLines, sourceIndex, matchLines));
	if (matches.length > 1) throw new Error(formatMatchAmbiguousError(path, fileLines, sourceIndex, matches));
	return matches[0];
}

function resolveJsonEdit(path: string, edit: HashlineJsonEdit, fileLines: string[], sourceIndex: number): ResolvedJsonEdit {
	const match = resolveMatch(path, fileLines, edit.match, sourceIndex);
	if (edit.op === "replace") {
		return {
			op: "replace",
			index: match.startLine - 1,
			startLine: match.startLine,
			endLine: match.endLine,
			lines: edit.lines,
			sourceIndex,
		};
	}
	if (edit.op === "delete") {
		return {
			op: "delete",
			index: match.startLine - 1,
			startLine: match.startLine,
			endLine: match.endLine,
			sourceIndex,
		};
	}
	if (edit.op === "insert_before") {
		return {
			op: "insert",
			index: match.startLine - 1,
			line: match.startLine,
			lines: edit.lines,
			sourceIndex,
		};
	}
	return {
		op: "insert",
		index: match.endLine,
		line: match.endLine,
		lines: edit.lines,
		sourceIndex,
	};
}

function validateNoConflicts(edits: ResolvedJsonEdit[]): void {
	const ranges = edits
		.filter((edit): edit is Extract<ResolvedJsonEdit, { op: "replace" | "delete" }> => edit.op === "replace" || edit.op === "delete")
		.sort((a, b) => a.startLine - b.startLine);

	for (let index = 1; index < ranges.length; index++) {
		const previous = ranges[index - 1];
		const current = ranges[index];
		if (current.startLine <= previous.endLine) {
			throw new Error(`overlap: edits[${previous.sourceIndex}] and edits[${current.sourceIndex}] target overlapping ranges.`);
		}
	}

	const insertionPoints = new Map<number, number>();
	for (const edit of edits) {
		if (edit.op !== "insert") continue;
		for (const range of ranges) {
			if (edit.line >= range.startLine && edit.line <= range.endLine) {
				throw new Error(`overlap: edits[${edit.sourceIndex}] inserts at line ${edit.line}, which is inside edits[${range.sourceIndex}] range ${range.startLine}..${range.endLine}. Split into separate calls.`);
			}
		}
		const previous = insertionPoints.get(edit.index);
		if (previous !== undefined) {
			throw new Error(`overlap: edits[${previous}] and edits[${edit.sourceIndex}] insert at the same position. Split into separate calls for deterministic order.`);
		}
		insertionPoints.set(edit.index, edit.sourceIndex);
	}
}

export function applyHashlineJsonEdits(path: string, text: string, edits: HashlineJsonEdit[]): HashlineJsonApplyResult {
	const fileLines = text.split("\n");
	const resolved = edits.map((edit, index) => resolveJsonEdit(path, edit, fileLines, index));
	validateNoConflicts(resolved);

	const nextLines = [...fileLines];
	for (const edit of [...resolved].sort((a, b) => b.index - a.index)) {
		if (edit.op === "replace") {
			nextLines.splice(edit.index, edit.endLine - edit.startLine + 1, ...edit.lines);
		} else if (edit.op === "delete") {
			nextLines.splice(edit.index, edit.endLine - edit.startLine + 1);
		} else {
			nextLines.splice(edit.index, 0, ...edit.lines);
		}
	}

	const lines = nextLines.join("\n");
	return { lines, changed: lines !== text };
}
