import { stat, readFile } from "node:fs/promises";
import path from "node:path";
import type { ImageInfo, SupportedImageMimeType } from "./types.ts";

const DEFAULT_MAX_BYTES = 20 * 1024 * 1024;
const MIN_MAX_BYTES = 1;
const MAX_MAX_BYTES = 50 * 1024 * 1024;

export function clampMaxBytes(value: number | undefined): number {
  if (!Number.isFinite(value ?? NaN)) return DEFAULT_MAX_BYTES;
  return Math.min(MAX_MAX_BYTES, Math.max(MIN_MAX_BYTES, Math.trunc(value ?? DEFAULT_MAX_BYTES)));
}

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KiB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MiB`;
}

export function detectImageMimeType(buffer: Buffer): SupportedImageMimeType | undefined {
  if (buffer.length >= 8 && buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return "image/png";
  if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) return "image/jpeg";
  if (buffer.length >= 6 && (buffer.subarray(0, 6).toString("ascii") === "GIF87a" || buffer.subarray(0, 6).toString("ascii") === "GIF89a")) return "image/gif";
  if (buffer.length >= 12 && buffer.subarray(0, 4).toString("ascii") === "RIFF" && buffer.subarray(8, 12).toString("ascii") === "WEBP") return "image/webp";
  return undefined;
}

export function readImageDimensions(buffer: Buffer, mimeType: SupportedImageMimeType): { width?: number; height?: number } {
  if (mimeType === "image/png" && buffer.length >= 24) return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
  if (mimeType === "image/gif" && buffer.length >= 10) return { width: buffer.readUInt16LE(6), height: buffer.readUInt16LE(8) };
  if (mimeType === "image/webp" && buffer.length >= 30) return readWebpDimensions(buffer);
  if (mimeType === "image/jpeg") return readJpegDimensions(buffer);
  return {};
}

function readJpegDimensions(buffer: Buffer): { width?: number; height?: number } {
  let offset = 2;
  while (offset + 9 < buffer.length) {
    if (buffer[offset] !== 0xff) return {};
    const marker = buffer[offset + 1];
    const length = buffer.readUInt16BE(offset + 2);
    if (length < 2) return {};
    if ((marker >= 0xc0 && marker <= 0xc3) || (marker >= 0xc5 && marker <= 0xc7) || (marker >= 0xc9 && marker <= 0xcb) || (marker >= 0xcd && marker <= 0xcf)) {
      return { height: buffer.readUInt16BE(offset + 5), width: buffer.readUInt16BE(offset + 7) };
    }
    offset += 2 + length;
  }
  return {};
}

function readWebpDimensions(buffer: Buffer): { width?: number; height?: number } {
  const chunkType = buffer.subarray(12, 16).toString("ascii");
  if (chunkType === "VP8 " && buffer.length >= 30) return { width: buffer.readUInt16LE(26) & 0x3fff, height: buffer.readUInt16LE(28) & 0x3fff };
  if (chunkType === "VP8L" && buffer.length >= 25) {
    const bits = buffer.readUInt32LE(21);
    return { width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1 };
  }
  if (chunkType === "VP8X" && buffer.length >= 30) return { width: 1 + buffer.readUIntLE(24, 3), height: 1 + buffer.readUIntLE(27, 3) };
  return {};
}

export async function loadImage(filePath: string, maxBytes: number): Promise<{ buffer: Buffer; info: ImageInfo }> {
  const absolutePath = path.resolve(filePath);
  const fileStat = await stat(absolutePath);
  if (!fileStat.isFile()) throw new Error(`Not a file: ${absolutePath}`);
  if (fileStat.size > maxBytes) throw new Error(`Image too large: ${formatBytes(fileStat.size)} exceeds maxBytes ${formatBytes(maxBytes)}. Raise maxBytes if intended.`);

  const buffer = await readFile(absolutePath);
  const mimeType = detectImageMimeType(buffer);
  if (!mimeType) throw new Error("Unsupported image type. Supported: png, jpeg, gif, webp.");

  const dimensions = readImageDimensions(buffer, mimeType);
  return { buffer, info: { path: absolutePath, mimeType, bytes: buffer.length, ...dimensions } };
}
