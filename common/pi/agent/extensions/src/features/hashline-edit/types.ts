export type CreateFileParams = {
  path: string;
  content: string;
};

export const AUTO_FULL_FILE_LINES = 1200;
export const MAX_TEXT_FILE_BYTES = 10 * 1024 * 1024;
