export const SUPPORTED_IMAGE_MIME_TYPES = ["image/png", "image/jpeg", "image/gif", "image/webp"] as const;

export type SupportedImageMimeType = (typeof SUPPORTED_IMAGE_MIME_TYPES)[number];

export interface ReadImageParams {
  path: string;
  maxBytes?: number;
}

export interface ImageInfo {
  path: string;
  mimeType: SupportedImageMimeType;
  bytes: number;
  width?: number;
  height?: number;
  modelSupportsImages?: boolean;
}
