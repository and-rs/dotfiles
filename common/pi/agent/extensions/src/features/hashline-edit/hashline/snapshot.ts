import { createHash } from "node:crypto";

export function computeHashlineSnapshotId(normalizedText: string): string {
	return `sha256:${createHash("sha256").update(normalizedText, "utf8").digest("hex").slice(0, 16)}`;
}
