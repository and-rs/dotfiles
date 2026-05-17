import { Text } from "@earendil-works/pi-tui";

export function renderToolCall(title: string, accent: string, theme: { fg: (name: string, text: string) => string; bold: (text: string) => string }): Text {
  return new Text(`${theme.fg("toolTitle", theme.bold(title))} ${theme.fg("accent", accent)}`, 0, 0);
}

export function renderToolResult(text: string, previewLines: number, expanded: boolean, theme: { fg: (name: string, text: string) => string }): Text {
  if (!expanded) return new Text(theme.fg("success", text.split("\n").slice(1, previewLines + 1).join(" · ")), 0, 0);
  return new Text(`\n${theme.fg("toolOutput", text)}`, 0, 0);
}
