import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import StyledEditor from "./styled-editor";

export default function registerEditorEvents(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) return;
    ctx.ui.setEditorComponent(
      (tui, editorTheme, keybindings) =>
        new StyledEditor(tui, editorTheme, keybindings, ctx.ui.theme),
    );
  });

  pi.on("session_shutdown", (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setEditorComponent(undefined);
  });
}
