import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { CheckpointDetails } from "./types.ts";

export const BLOCKED_PUSH_RE = /(^|[\s;&|()])git\s+push(\s|$)/;
export const CHECKPOINT_CUSTOM_TYPE = "pi-checkpoint";

export type SendCheckpointMessage = (pi: ExtensionAPI, details: CheckpointDetails) => Promise<void>;
