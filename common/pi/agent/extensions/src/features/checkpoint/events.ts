import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { BLOCKED_PUSH_RE, type SendCheckpointMessage } from "./shared.ts";
import { changedFilesSince, checkpointThresholdReached, flushCheckpoint, snapshot } from "./git.ts";
import type { BatchState, CheckpointDetails, Snapshot } from "./types.ts";

export function registerCheckpointEvents(pi: ExtensionAPI, sendCheckpointMessage: SendCheckpointMessage): void {
  let turnSnapshot: Snapshot | null = null;
  let pendingBatch: BatchState | null = null;

  pi.on("tool_call", (event) => {
    if (event.toolName !== "bash") return;
    const command = typeof event.input.command === "string" ? event.input.command : "";
    if (!BLOCKED_PUSH_RE.test(command)) return;
    return { block: true, reason: "git push is blocked by pi-checkpoint; push manually outside Pi." };
  });

  pi.on("turn_start", async (_event, ctx) => {
    if (!ctx.hasUI) {
      turnSnapshot = null;
      return;
    }
    turnSnapshot = await snapshot(pi, ctx.cwd);
  });

  pi.on("turn_end", async (_event, ctx) => {
    if (!ctx.hasUI) {
      turnSnapshot = null;
      return;
    }

    const before = turnSnapshot;
    turnSnapshot = null;
    if (!before?.ok || !before.root) return;

    const after = await snapshot(pi, ctx.cwd);
    if (!after.ok || !after.root) {
      if (pendingBatch) {
        await sendCheckpointMessage(pi, { status: "skipped", reason: after.reason ?? "git state unavailable" });
        pendingBatch = null;
      }
      return;
    }

    const changedFiles = changedFilesSince(before, after);

    if (!pendingBatch) {
      if (before.dirtyFiles.size !== 0 || changedFiles.length === 0) return;
      pendingBatch = {
        root: after.root,
        files: new Set(changedFiles),
        turns: 1,
      };
      if (checkpointThresholdReached(pendingBatch)) {
        const batch = pendingBatch;
        pendingBatch = null;
        await flushCheckpoint(pi, ctx, batch, sendCheckpointMessage);
      }
      return;
    }

    if (pendingBatch.root !== after.root) {
      await sendCheckpointMessage(pi, { status: "skipped", reason: "git root changed during checkpoint batch" });
      pendingBatch = null;
      return;
    }

    for (const file of changedFiles) pendingBatch.files.add(file);
    if (changedFiles.length > 0) pendingBatch.turns += 1;

    if (changedFiles.length === 0 || checkpointThresholdReached(pendingBatch)) {
      const batch = pendingBatch;
      pendingBatch = null;
      await flushCheckpoint(pi, ctx, batch, sendCheckpointMessage);
    }
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (!pendingBatch) return;
    const batch = pendingBatch;
    pendingBatch = null;
    await flushCheckpoint(pi, ctx, batch, sendCheckpointMessage);
  });
}
