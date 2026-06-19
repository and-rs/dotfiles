import { homedir } from "node:os";
import { resolve } from "node:path";


export type CreateFileParams = {
  path: string;
  content: string;
};

export const AUTO_FULL_FILE_LINES = 1200;
export const HOME_DIR = resolve(homedir());
export const MAX_TEXT_FILE_BYTES = 10 * 1024 * 1024;