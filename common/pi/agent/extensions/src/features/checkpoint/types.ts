export type Snapshot = {
  cwd: string;
  root: string | null;
  gitDir: string | null;
  dirtyFiles: Set<string>;
  ok: boolean;
  reason?: string;
};

export type CheckpointDetails = {
  status: "created" | "skipped" | "blocked" | "failed";
  hash?: string;
  files?: string[];
  reason?: string;
};

export type BatchState = {
  root: string;
  files: Set<string>;
  turns: number;
};
