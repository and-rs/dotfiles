import { HashlineMismatchError, parseTag } from "./anchors";
import { computeLineHash, formatHashLines } from "./hash";
import type { Anchor } from "./types";

export type HashlineJsonEditParams = {
	path: string;
	snapshotId: string;
	edits: HashlineJsonEdit[];
};

export type HashlineJsonEdit =
	| { op: "replace"; start: string; end: string; lines: string[] }
	| { op: "delete"; start: string; end: string }
	| { op: "insert_before"; anchor: string; lines: string[] }
	| { op: "insert_after"; anchor: string; lines: string[] };

export type HashlineJsonApplyResult = {
	lines: string;
	changed: boolean;
};

type ResolvedJsonEdit =
	| { op: "replace"; index: number; startLine: number; endLine: number; lines: string[]; sourceIndex: number }
	| { op: "delete"; index: number; startLine: number; endLine: number; sourceIndex: number }
	| { op: "insert"; index: number; line: number; lines: string[]; sourceIndex: number };

type JsonRecord = Record<string, unknown>;

const PARAM_KEYS = new Set(["path", "snapshotId", "edits"]);
const REPLACE_KEYS = new Set(["op", "start", "end", "lines"]);
const DELETE_KEYS = new Set(["op", "start", "end"]);
const INSERT_KEYS = new Set(["op", "anchor", "lines"]);

function isRecord(value: unknown): value is JsonRecord {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function rejectUnknownKeys(value: JsonRecord, allowed: Set<string>, loc: string): void {
	const unknown = Object.keys(value).filter(key => !allowed.has(key));
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
		return { op, start: requireString(value, "start", loc), end: requireString(value, "end", loc), lines: requireLines(value, "lines", loc) };
	}
	if (op === "delete") {
		rejectUnknownKeys(value, DELETE_KEYS, loc);
		return { op, start: requireString(value, "start", loc), end: requireString(value, "end", loc) };
	}
	if (op === "insert_before" || op === "insert_after") {
		rejectUnknownKeys(value, INSERT_KEYS, loc);
		return { op, anchor: requireString(value, "anchor", loc), lines: requireLines(value, "lines", loc) };
	}
	throw new Error(`schema_invalid: ${loc}.op must be one of replace, delete, insert_before, insert_after.`);
}

export function parseHashlineJsonEditParams(value: unknown): HashlineJsonEditParams {
	if (!isRecord(value)) throw new Error("schema_invalid: hashline-edit parameters must be an object.");
	rejectUnknownKeys(value, PARAM_KEYS, "params");
	const path = requireString(value, "path", "params");
	const snapshotId = requireString(value, "snapshotId", "params");
	const rawEdits = value.edits;
	if (!Array.isArray(rawEdits) || rawEdits.length === 0) {
		throw new Error("schema_invalid: params.edits must be a non-empty array.");
	}
	if (rawEdits.length > 8) {
		throw new Error("schema_invalid: params.edits may contain at most 8 edits. Split large edits into separate hashline-edit calls.");
	}
	return { path, snapshotId, edits: rawEdits.map(parseJsonEdit) };
}

function formatFreshContext(fileLines: string[], centerLine: number, radius = 3): string {
	const start = Math.max(1, centerLine - radius);
	const end = Math.min(fileLines.length, centerLine + radius);
	return formatHashLines(fileLines.slice(start - 1, end).join("\n"), start);
}

export function formatSnapshotStaleError(
	path: string,
	expectedSnapshotId: string,
	actualSnapshotId: string,
	fileLines: string[],
	edits: HashlineJsonEdit[],
): string {
	const line = firstReferencedLine(edits) ?? 1;
	return [
		"hashline-edit rejected: snapshot_stale",
		"No changes were applied.",
		`path: ${path}`,
		`expected snapshotId: ${expectedSnapshotId}`,
		`current snapshotId: ${actualSnapshotId}`,
		"Use the fresh anchored context below to retry with the current snapshotId.",
		"",
		formatFreshContext(fileLines, line),
	].join("\n");
}

function firstReferencedLine(edits: HashlineJsonEdit[]): number | undefined {
	for (const edit of edits) {
		const refs = edit.op === "insert_before" || edit.op === "insert_after" ? [edit.anchor] : [edit.start, edit.end];
		for (const ref of refs) {
			try {
				return parseTag(ref).line;
			} catch {
				continue;
			}
		}
	}
	return undefined;
}

function parseAnchor(ref: string, fileLines: string[], editIndex: number, field: string): Anchor {
	let anchor: Anchor;
	try {
		anchor = parseTag(ref);
	} catch (error) {
		throw new Error(`schema_invalid: edits[${editIndex}].${field}: ${(error as Error).message}`);
	}
	if (anchor.line < 1 || anchor.line > fileLines.length) {
		throw new Error(
			[
				"hashline-edit rejected: anchor_missing",
				"No changes were applied.",
				`edits[${editIndex}].${field}: line ${anchor.line} does not exist; file has ${fileLines.length} lines.`,
			].join("\n"),
		);
	}
	const actual = computeLineHash(anchor.line, fileLines[anchor.line - 1] ?? "");
	if (actual !== anchor.hash) {
		throw new HashlineMismatchError([{ line: anchor.line, expected: anchor.hash, actual }], fileLines);
	}
	return anchor;
}

function resolveJsonEdit(edit: HashlineJsonEdit, fileLines: string[], sourceIndex: number): ResolvedJsonEdit {
	if (edit.op === "replace" || edit.op === "delete") {
		const start = parseAnchor(edit.start, fileLines, sourceIndex, "start");
		const end = parseAnchor(edit.end, fileLines, sourceIndex, "end");
		if (start.line > end.line) {
			throw new Error(`range_invalid: edits[${sourceIndex}] start anchor must be before or equal to end anchor.`);
		}
		return edit.op === "replace"
			? { op: "replace", index: start.line - 1, startLine: start.line, endLine: end.line, lines: edit.lines, sourceIndex }
			: { op: "delete", index: start.line - 1, startLine: start.line, endLine: end.line, sourceIndex };
	}

	const anchor = parseAnchor(edit.anchor, fileLines, sourceIndex, "anchor");
	const index = edit.op === "insert_before" ? anchor.line - 1 : anchor.line;
	return { op: "insert", index, line: anchor.line, lines: edit.lines, sourceIndex };
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

export function applyHashlineJsonEdits(text: string, edits: HashlineJsonEdit[]): HashlineJsonApplyResult {
	const fileLines = text.split("\n");
	const resolved = edits.map((edit, index) => resolveJsonEdit(edit, fileLines, index));
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
