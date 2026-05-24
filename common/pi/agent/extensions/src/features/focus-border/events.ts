import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { FocusBorderEditor } from "./ui.ts";
import { FOCUS_REPORTING_OFF, FOCUS_REPORTING_ON } from "./types.ts";

export function registerFocusBorderEvents(pi: ExtensionAPI): void {
  let terminalFocused = true;
  let unsubscribeTerminalFocus: (() => void) | null = null;
  let requestRender: (() => void) | null = null;

  const writeFocusReporting = (sequence: string): void => {
    try {
      process.stdout.write(sequence);
    } catch {
      return;
    }
  };

  const enableFocusReporting = (): void => writeFocusReporting(FOCUS_REPORTING_ON);
  const disableFocusReporting = (): void => writeFocusReporting(FOCUS_REPORTING_OFF);

  const updateTerminalFocus = (focused: boolean): void => {
    if (terminalFocused === focused) {
      return;
    }

    terminalFocused = focused;
    requestRender?.();
  };

  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) {
      return;
    }

    terminalFocused = true;
    enableFocusReporting();
    unsubscribeTerminalFocus?.();
    unsubscribeTerminalFocus = ctx.ui.onTerminalInput((data) => {
      let sawFocusReport = false;
      if (data.includes("\u001b[I")) {
        updateTerminalFocus(true);
        sawFocusReport = true;
      }
      if (data.includes("\u001b[O")) {
        updateTerminalFocus(false);
        sawFocusReport = true;
      }
      return sawFocusReport ? { consume: true } : undefined;
    });

    ctx.ui.setEditorComponent((tui, editorTheme, keybindings) => {
      requestRender = () => tui.requestRender();
      return new FocusBorderEditor(
        tui,
        editorTheme,
        keybindings,
        (text: string) => ctx.ui.theme.fg("borderMuted", text),
        () => terminalFocused,
      );
    });
  });

  pi.on("session_shutdown", (_event, ctx) => {
    if (!ctx.hasUI) {
      return;
    }
    ctx.ui.setEditorComponent(undefined);
    disableFocusReporting();
    unsubscribeTerminalFocus?.();
    unsubscribeTerminalFocus = null;
    requestRender = null;
  });
}
