import { CustomEditor } from "@earendil-works/pi-coding-agent";
import {
  CURSOR_MARKER,
  getKeybindings,
  matchesKey,
  truncateToWidth,
  visibleWidth,
} from "@earendil-works/pi-tui";
import {
  EditorRenderInternals,
  validateEditorRenderInternals,
  validateLayoutLines,
} from "./validate-styled-editor";

export default class StyledEditor extends CustomEditor {
  private hasValidatedInternals: boolean = false;
  private borderChars = {
    tl: "┏",
    th: "━",
    tr: "┓",
    rh: "┃",
    br: "┛",
    bh: "━",
    bl: "┗",
    lh: "┃",
  };

  private renderBorder(
    width: number,
    left: string,
    horizontal: string,
    right: string,
    indicator?: string,
  ): string {
    if (width <= 0) return "";
    if (width === 1) return this.borderColor(left);

    const innerWidth = width - 2;
    const content = indicator
      ? truncateToWidth(indicator, innerWidth) +
        horizontal.repeat(
          Math.max(0, innerWidth - visibleWidth(indicator)),
        )
      : horizontal.repeat(innerWidth);
    return this.borderColor(`${left}${content}${right}`);
  }

  private renderTopBorder(width: number, scrollOffset: number): string {
    return this.renderBorder(
      width,
      this.borderChars.tl,
      this.borderChars.th,
      this.borderChars.tr,
      scrollOffset > 0 ? ` ↑ ${scrollOffset} more ` : undefined,
    );
  }

  private renderBottomBorder(width: number, linesBelow: number): string {
    return this.renderBorder(
      width,
      this.borderChars.bl,
      this.borderChars.bh,
      this.borderChars.br,
      linesBelow > 0 ? ` ↓ ${linesBelow} more ` : undefined,
    );
  }

  private renderContentLine(
    width: number,
    content: string,
    contentWidth: number,
  ): string {
    if (width <= 0) return "";
    if (width === 1) return this.borderColor(this.borderChars.lh);

    const innerWidth = Math.max(0, width - 2);
    const text = truncateToWidth(content, Math.min(contentWidth, innerWidth));
    const padding = " ".repeat(Math.max(0, innerWidth - visibleWidth(text)));
    return `${this.borderColor(this.borderChars.lh)}${text}${padding}${this.borderColor(this.borderChars.rh)}`;
  }

  override render(width: number): string[] {
    // This will fail fast. If internal api changes, please fix accordingly, no graceful fail UI.
    const editor = !this.hasValidatedInternals
      ? validateEditorRenderInternals(this)
      : (this as unknown as EditorRenderInternals);

    const frameWidth = Math.max(0, width - 2);
    const maxPadding = Math.max(0, Math.floor((frameWidth - 1) / 2));
    const paddingX = Math.min(editor.paddingX, maxPadding);
    const contentWidth = Math.max(1, frameWidth - paddingX * 2);
    const layoutWidth = Math.max(1, contentWidth - (paddingX ? 0 : 1));
    editor.lastWidth = layoutWidth;
    const layoutLines = editor.layoutText(layoutWidth);

    if (!this.hasValidatedInternals) {
      validateLayoutLines(layoutLines);
      this.hasValidatedInternals = true;
    }

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

    result.push(this.renderTopBorder(width, editor.scrollOffset));

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
      result.push(
        this.renderContentLine(
          width,
          `${leftPadding}${displayText}${padding}${lineRightPadding}`,
            frameWidth,
        ),
      );
    }

    const linesBelow =
      layoutLines.length - (editor.scrollOffset + visibleLines.length);
    result.push(this.renderBottomBorder(width, linesBelow));

    if (editor.autocompleteState && editor.autocompleteList) {
      for (const line of editor.autocompleteList.render(contentWidth)) {
        const linePadding = " ".repeat(
          Math.max(0, contentWidth - visibleWidth(line)),
        );
        result.push(
          this.renderContentLine(
            width,
            `${leftPadding}${line}${linePadding}${rightPadding}`,
          frameWidth,
          ),
        );
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
