import { CustomEditor } from "@earendil-works/pi-coding-agent";
import {
  CURSOR_MARKER,
  getKeybindings,
  matchesKey,
  truncateToWidth,
  visibleWidth,
} from "@earendil-works/pi-tui";

interface LayoutLine {
  text: string;
  hasCursor: boolean;
  cursorPos?: number;
}

interface EditorRenderInternals {
  paddingX: number;
  lastWidth: number;
  scrollOffset: number;
  autocompleteState: unknown;
  autocompleteList?: {
    render(width: number): string[];
    handleInput(data: string): void;
  };
  layoutText(width: number): LayoutLine[];
  segment(text: string, mode: "word" | "grapheme"): Iterable<Intl.SegmentData>;
}

export default class StyledEditor extends CustomEditor {
  override render(width: number): string[] {
    const editor = this as unknown as EditorRenderInternals;
    const maxPadding = Math.max(0, Math.floor((width - 1) / 2));
    const paddingX = Math.min(editor.paddingX, maxPadding);
    const contentWidth = Math.max(1, width - paddingX * 2);
    const layoutWidth = Math.max(1, contentWidth - (paddingX ? 0 : 1));
    editor.lastWidth = layoutWidth;

    const horizontal = this.borderColor("─");
    const layoutLines = editor.layoutText(layoutWidth);
    const maxVisibleLines = Math.max(
      5,
      Math.floor(this.tui.terminal.rows * 0.3),
    );

    let cursorLineIndex = layoutLines.findIndex((line) => line.hasCursor);
    if (cursorLineIndex === -1) cursorLineIndex = 0;

    if (cursorLineIndex < editor.scrollOffset) {
      editor.scrollOffset = cursorLineIndex;
    } else if (cursorLineIndex >= editor.scrollOffset + maxVisibleLines) {
      editor.scrollOffset = cursorLineIndex - maxVisibleLines + 1;
    }

    const maxScrollOffset = Math.max(0, layoutLines.length - maxVisibleLines);
    editor.scrollOffset = Math.max(
      0,
      Math.min(editor.scrollOffset, maxScrollOffset),
    );

    const visibleLines = layoutLines.slice(
      editor.scrollOffset,
      editor.scrollOffset + maxVisibleLines,
    );
    const result: string[] = [];
    const leftPadding = " ".repeat(paddingX);
    const rightPadding = leftPadding;

    if (editor.scrollOffset > 0) {
      const indicator = `─── ↑ ${editor.scrollOffset} more `;
      const remaining = width - visibleWidth(indicator);
      result.push(
        this.borderColor(
          remaining >= 0
            ? indicator + "─".repeat(remaining)
            : truncateToWidth(indicator, width),
        ),
      );
    } else {
      result.push(horizontal.repeat(width));
    }

    for (const layoutLine of visibleLines) {
      let displayText = layoutLine.text;
      let lineVisibleWidth = visibleWidth(layoutLine.text);
      let cursorInPadding = false;

      if (layoutLine.hasCursor && layoutLine.cursorPos !== undefined) {
        const before = displayText.slice(0, layoutLine.cursorPos);
        const after = displayText.slice(layoutLine.cursorPos);
        const marker = this.focused ? CURSOR_MARKER : "";

        if (after.length > 0) {
          const firstGrapheme =
            [...editor.segment(after, "grapheme")][0]?.segment ?? "";
          const restAfter = after.slice(firstGrapheme.length);
          displayText = `${before}${marker}\x1b[7m${firstGrapheme}\x1b[0m${restAfter}`;
        } else {
          displayText = `${before}${marker}\x1b[7m \x1b[0m`;
          lineVisibleWidth += 1;
          cursorInPadding = lineVisibleWidth > contentWidth && paddingX > 0;
        }
      }

      const padding = " ".repeat(Math.max(0, contentWidth - lineVisibleWidth));
      const lineRightPadding = cursorInPadding
        ? rightPadding.slice(1)
        : rightPadding;
      result.push(`${leftPadding}${displayText}${padding}${lineRightPadding}`);
    }

    const linesBelow =
      layoutLines.length - (editor.scrollOffset + visibleLines.length);
    if (linesBelow > 0) {
      const indicator = `─── ↓ ${linesBelow} more `;
      const remaining = width - visibleWidth(indicator);
      result.push(
        this.borderColor(indicator + "─".repeat(Math.max(0, remaining))),
      );
    } else {
      result.push(horizontal.repeat(width));
    }

    if (editor.autocompleteState && editor.autocompleteList) {
      for (const line of editor.autocompleteList.render(contentWidth)) {
        const linePadding = " ".repeat(
          Math.max(0, contentWidth - visibleWidth(line)),
        );
        result.push(`${leftPadding}${line}${linePadding}${rightPadding}`);
      }
    }

    return result;
  }

  override handleInput(data: string): void {
    const editor = this as unknown as EditorRenderInternals;
    const keybindings = getKeybindings();

    if (editor.autocompleteState && editor.autocompleteList) {
      const direction = matchesKey(data, "ctrl+p")
        ? "tui.select.up"
        : matchesKey(data, "ctrl+n")
          ? "tui.select.down"
          : keybindings.matches(data, "tui.select.up")
            ? "tui.select.up"
            : keybindings.matches(data, "tui.select.down")
              ? "tui.select.down"
              : undefined;

      if (direction) {
        const selectInput = direction === "tui.select.up" ? "\x1b[A" : "\x1b[B";
        editor.autocompleteList.handleInput(selectInput);
        return;
      }
    }

    super.handleInput(data);
  }
}
