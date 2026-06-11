import { Text } from "@earendil-works/pi-tui";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { clampMaxBytes, formatBytes, loadImage } from "./image.ts";
import type { ImageInfo, ReadImageParams } from "./types.ts";

interface ToolContext {
  model?: { input?: string[] };
}

function formatInfo(info: ImageInfo): string {
  const dimensions = info.width && info.height ? `${info.width}x${info.height}` : "dimensions unknown";
  const warning = info.modelSupportsImages === false ? "\n[Warning: current model does not advertise image input support.]" : "";
  return `Read image file [${info.mimeType}] ${dimensions}, ${formatBytes(info.bytes)}\n${info.path}${warning}`;
}

export default function registerReadImageFeature(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "read-image",
    label: "Read Image",
    description: "Read an image file and send actual image bytes to the model as an image attachment. Supports png, jpeg, gif, webp. No OCR.",
    promptSnippet: "Use read-image to inspect image files visually. It sends actual image bytes to vision-capable models; do not use local OCR.",
    promptGuidelines: [
      "Use read-image for screenshots, photos, diagrams, UI captures, and other visual files.",
      "Do not use OCR or shell/base64 workarounds for images unless read-image fails.",
      "If model does not support images, switch to an image-capable model before using read-image.",
    ],
    parameters: Type.Object({
      path: Type.String({ description: "Path to png, jpeg, gif, or webp image file. Relative paths resolve from current working directory." }),
      maxBytes: Type.Optional(Type.Integer({ minimum: 1, maximum: 50 * 1024 * 1024, description: "Safety cap for file size in bytes. Default 20 MiB; max 50 MiB." })),
    }),
    execute: async (_toolCallId, params: ReadImageParams, _signal, _onUpdate, ctx?: ToolContext) => {
      const maxBytes = clampMaxBytes(params.maxBytes);
      const { buffer, info } = await loadImage(params.path, maxBytes);
      const modelSupportsImages = ctx?.model?.input?.includes("image");
      const details: ImageInfo = { ...info, modelSupportsImages };
      return {
        content: [
          { type: "text", text: formatInfo(details) },
          { type: "image", data: buffer.toString("base64"), mimeType: info.mimeType },
        ],
        details,
      };
    },
    renderCall(args, theme) {
      return new Text(`${theme.fg("toolTitle", theme.bold("read-image"))} ${theme.fg("accent", String(args.path ?? ""))}`, 0, 0);
    },
    renderResult(result, { expanded }, theme) {
      const info = result.details as ImageInfo | undefined;
      if (!info) return new Text(theme.fg("warning", "No image details"), 0, 0);
      const dimensions = info.width && info.height ? `${info.width}x${info.height}` : "unknown size";
      const summary = `${info.mimeType} · ${dimensions} · ${formatBytes(info.bytes)} · attached to model`;
      const warning = info.modelSupportsImages === false ? `\n${theme.fg("warning", "Current model may not support image input")}` : "";
      const pathLine = expanded ? `\n${theme.fg("muted", info.path)}` : "";
      return new Text(`${theme.fg("success", summary)}${warning}${pathLine}`, 0, 0);
    },
  });
}
