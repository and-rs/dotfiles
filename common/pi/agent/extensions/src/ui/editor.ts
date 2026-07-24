import { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import StyledEditor from "./styled-editor";

export default function registerEditorEvents(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) return;
    ctx.ui.setEditorComponent(
      (tui, theme, keybindings) => new StyledEditor(tui, theme, keybindings),
    );
  });

  pi.on("session_shutdown", (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setEditorComponent(undefined);
  });
}
