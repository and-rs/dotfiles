import { Text } from "@earendil-works/pi-tui";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { CHECKPOINT_CUSTOM_TYPE, type SendCheckpointMessage } from "./shared.ts";
import type { CheckpointDetails } from "./types.ts";

function formatTreeItems(items: string[], indent = ""): string[] {
  return items.map((item, index) => `${indent}${index === items.length - 1 ? "└──" : "├──"} ${item}`);
}

export function formatCheckpointMessage(details: CheckpointDetails): string {
  if (details.status === "created") {
    const files = details.files ?? [];
    return [`created [PI] ${details.hash ?? "unknown"}`, "└── files", ...formatTreeItems(files, "    ")].join("\n");
  }
  return [`${details.status}`, `└── ${details.reason ?? "no details"}`].join("\n");
}

export function registerCheckpointRenderers(pi: ExtensionAPI): SendCheckpointMessage {
  pi.registerMessageRenderer<CheckpointDetails>(CHECKPOINT_CUSTOM_TYPE, (message, _options, theme) => {
    const content = typeof message.content === "string" ? message.content : "";
    return new Text(`${theme.fg("success", "checkpoint")}\n${theme.fg("muted", content)}`, 0, 0);
  });

  return async (runtimePi: ExtensionAPI, details: CheckpointDetails): Promise<void> => {
    runtimePi.sendMessage({
      customType: CHECKPOINT_CUSTOM_TYPE,
      content: formatCheckpointMessage(details),
      display: true,
      details,
    }, { deliverAs: "steer" });
  };
}
