import { CustomEditor } from "@earendil-works/pi-coding-agent";

export type CustomEditorArgs = ConstructorParameters<typeof CustomEditor>;
export type BorderColor = (text: string) => string;

export const FOCUS_REPORTING_ON = "[?1004h";
export const FOCUS_REPORTING_OFF = "[?1004l";
