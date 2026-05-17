export type Phase = "off" | "tactic" | "exert" | "refine" | "temper";

export type ForgeState = {
  phase: Phase;
  touchedFiles: string[];
};

export type HashlineEditDetails = {
  files?: Array<{
    path?: string;
  }>;
};

export type FileCreateDetails = {
  path?: string;
};
