export interface HashMismatch {
  line: number;
  expected: string;
  actual: string;
}

export type Anchor = {
  line: number;
  hash: string;
  contentHint?: string;
};

export type HashlineCursor =
  | { kind: "bof" }
  | { kind: "eof" }
  | { kind: "before_anchor"; anchor: Anchor }
  | { kind: "after_anchor"; anchor: Anchor };

export type HashlineEdit =
  | { kind: "insert"; cursor: HashlineCursor; text: string; lineNum: number; index: number }
  | { kind: "delete"; anchor: Anchor; lineNum: number; index: number; oldAssertion?: string };

export interface HashlineApplyOptions {
  autoDropPureInsertDuplicates?: boolean;
}

export interface SplitHashlineOptions {
  cwd?: string;
  path?: string;
}

export interface HashlineSnapshot {
  lines: Map<number, string>;
}
