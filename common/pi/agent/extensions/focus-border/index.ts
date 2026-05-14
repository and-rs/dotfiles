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
  let unsubscribeProcessCleanup: (() => void) | null = null;

  const disableFocusReporting = () => {
    try {
      process.stdout.write(FOCUS_REPORTING_OFF);
    } catch {
      return;
    }
  };

  const registerProcessCleanup = () => {
    if (unsubscribeProcessCleanup) return;
    const onExit = () => disableFocusReporting();
    const onSigint = () => {
      disableFocusReporting();
      process.exit(130);
    };
    const onSigterm = () => {
      disableFocusReporting();
      process.exit(143);
    };
    process.once("exit", onExit);
    process.once("SIGINT", onSigint);
    process.once("SIGTERM", onSigterm);
    unsubscribeProcessCleanup = () => {
      process.off("exit", onExit);
      process.off("SIGINT", onSigint);
      process.off("SIGTERM", onSigterm);
      unsubscribeProcessCleanup = null;
    };
  };

  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) {
      return;
    }

    terminalFocused = true;
    process.stdout.write(FOCUS_REPORTING_ON);
    registerProcessCleanup();
    unsubscribeTerminalFocus?.();
    unsubscribeTerminalFocus = ctx.ui.onTerminalInput((data) => {
      if (data === "\u001b[I") {
        terminalFocused = true;
        requestRender?.();
      } else if (data === "\u001b[O") {
        terminalFocused = false;
        requestRender?.();
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
    unsubscribeProcessCleanup?.();
    requestRender = null;
  });
}
