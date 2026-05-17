import { homedir } from "node:os";
import { resolve } from "node:path";

export type ReadParams = {
  path: string;
  offset?: number;
  limit?: number;
};

export type EditParams = {
  input: string;
  path?: string;
  autoDropPureInsertDuplicates?: boolean;
};

export type CreateFileParams = {
  path: string;
  content: string;
};

export const DEFAULT_READ_LIMIT = 300;
export const MAX_READ_LIMIT = 2000;
export const READ_TRUNCATION_NOTICE = (start: number, end: number, total: number): string =>
  `[Showing lines ${start}-${end} of ${total}. Use :L${end + 1} to continue]`;
export const HOME_DIR = resolve(homedir());
export const MAX_TEXT_FILE_BYTES = 10 * 1024 * 1024;
