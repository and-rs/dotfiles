export interface HashMismatch {
  line: number;
  expected: string;
  actual: string;
}

export type Anchor = {
  line: number;
  hash: string;
};
