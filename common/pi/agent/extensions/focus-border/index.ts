import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

type CustomEditorArgs = ConstructorParameters<typeof CustomEditor>;
type BorderColor = (text: string) => string;

class FocusBorderEditor extends CustomEditor {
  constructor(
    tui: CustomEditorArgs[0],
    editorTheme: CustomEditorArgs[1],
    keybindings: CustomEditorArgs[2],
    private readonly unfocusedBorderColor: BorderColor,
    private readonly isTerminalFocused: () => boolean,
  ) {
    super(tui, editorTheme, keybindings);
  }

  render(width: number): string[] {
    const activeBorderColor = this.borderColor;
    this.borderColor = this.focused && this.isTerminalFocused() ? activeBorderColor : this.unfocusedBorderColor;
    try {
      return super.render(width);
    } finally {
      this.borderColor = activeBorderColor;
    }
  }
}

const FOCUS_REPORTING_ON = "\u001b[?1004h";
const FOCUS_REPORTING_OFF = "\u001b[?1004l";

export default function focusBorderExtension(pi: ExtensionAPI): void {
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
      if (data.includes("\u001b[I")) {
        updateTerminalFocus(true);
      }
      if (data.includes("\u001b[O")) {
        updateTerminalFocus(false);
      }
      return {};
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
