import { CustomEditor } from "@earendil-works/pi-coding-agent";
import type { BorderColor, CustomEditorArgs } from "./types.ts";

export class FocusBorderEditor extends CustomEditor {
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
