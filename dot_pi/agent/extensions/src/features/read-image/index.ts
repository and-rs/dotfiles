import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { clampMaxBytes, formatBytes, loadImage } from "./image.ts";
import type { ImageInfo, ReadImageParams } from "./types.ts";

function formatInfo(info: ImageInfo): string {
  let dimensions = "dimensions unknown";
  if (info.width && info.height) dimensions = `${info.width}x${info.height}`;
  let warning = "";
  if (info.modelSupportsImages === false) {
    warning =
      "\n[Warning: current model does not advertise image input support.]";
  }
  return `Read image file [${info.mimeType}] ${dimensions}, ${formatBytes(info.bytes)}\n${info.path}${warning}`;
}

export default function registerReadImageFeature(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "read-image",
    label: "Read Image",
    description:
      "Read an image file and send actual image bytes to model as image attachment. Supports png, jpeg, gif, webp. No OCR.",
    promptSnippet:
      "Use read-image to inspect image files visually. It sends actual image bytes to vision-capable models; do not use local OCR.",
    promptGuidelines: [
      "Use read-image for screenshots, photos, diagrams, UI captures, and other visual files.",
      "Do not use OCR or shell/base64 workarounds for images unless read-image fails.",
      "If model does not support images, switch to an image-capable model before using read-image.",
    ],
    parameters: Type.Object({
      path: Type.String({
        description:
          "Path to png, jpeg, gif, or webp image file. Relative paths resolve from current working directory.",
      }),
      maxBytes: Type.Optional(
        Type.Integer({
          minimum: 1,
          maximum: 50 * 1024 * 1024,
          description:
            "Safety cap for file size in bytes. Default 20 MiB; max 50 MiB.",
        }),
      ),
    }),
    execute: async (
      _toolCallId,
      params: ReadImageParams,
      _signal,
      _onUpdate,
      ctx,
    ) => {
      const maxBytes = clampMaxBytes(params.maxBytes);
      const { buffer, info } = await loadImage(params.path, maxBytes);
      const modelSupportsImages = ctx.model?.input?.includes("image");
      const details: ImageInfo = { ...info };
      if (modelSupportsImages !== undefined) {
        details.modelSupportsImages = modelSupportsImages;
      }
      return {
        content: [
          { type: "text", text: formatInfo(details) },
          {
            type: "image",
            data: buffer.toString("base64"),
            mimeType: info.mimeType,
          },
        ],
        details,
      };
    },
    renderCall(args, theme) {
      return new Text(
        `${theme.fg("toolTitle", theme.bold("read-image"))} ${theme.fg("accent", String(args.path ?? ""))}`,
        0,
        0,
      );
    },
    renderResult(result, _, theme) {
      const info = result.details as ImageInfo | undefined;
      if (!info) return new Text(theme.fg("warning", "No image details"), 0, 0);
      let dimensions = "unknown size";
      if (info.width && info.height)
        dimensions = `${info.width}x${info.height}`;

      const summary = `${info.mimeType} · ${dimensions} · ${formatBytes(info.bytes)} · attached to model`;

      let warning = "";
      if (info.modelSupportsImages === false) {
        warning = `\n${theme.fg("warning", "Current model may not support image input")}`;
      }

      const pathLine = `\n${theme.fg("muted", info.path)}`;
      return new Text(
        `${theme.fg("success", summary)}${warning}${pathLine}`,
        0,
        0,
      );
    },
  });
}
