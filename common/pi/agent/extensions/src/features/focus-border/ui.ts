import { CustomEditor } from "@earendil-works/pi-coding-agent";
import type { BorderColor, CustomEditorArgs } from "./types.ts";

const EDITOR_KEY_ALIASES = [
  ["tui.editor.cursorUp", "\u001b[A"],
  ["tui.editor.cursorDown", "\u001b[B"],
  ["tui.editor.cursorLeft", "\u001b[D"],
  ["tui.editor.cursorRight", "\u001b[C"],
] as const;

export class FocusBorderEditor extends CustomEditor {
  constructor(
    tui: CustomEditorArgs[0],
    editorTheme: CustomEditorArgs[1],
    private readonly editorKeybindings: CustomEditorArgs[2],
    private readonly unfocusedBorderColor: BorderColor,
    private readonly isTerminalFocused: () => boolean,
  ) {
    super(tui, editorTheme, editorKeybindings);
  }

  override handleInput(data: string): void {
    for (const [action, sequence] of EDITOR_KEY_ALIASES) {
      if (this.editorKeybindings.matches(data, action)) {
        super.handleInput(sequence);
        return;
      }
    }

    super.handleInput(data);
  }

  override render(width: number): string[] {
    const activeBorderColor = this.borderColor;
    this.borderColor = this.focused && this.isTerminalFocused() ? activeBorderColor : this.unfocusedBorderColor;
    try {
      return super.render(width);
    } finally {
      this.borderColor = activeBorderColor;
    }
  }
}
