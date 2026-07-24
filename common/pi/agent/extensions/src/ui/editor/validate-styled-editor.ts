export interface LayoutLine {
   text: string;
   hasCursor: boolean;
   cursorPos?: number;
}

export interface EditorRenderInternals {
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

export function validateLayoutLines(lines: unknown): LayoutLine[] {
   if (!Array.isArray(lines)) {
      throw Error("layoutLines passed is not an array");
   }
   lines.forEach((item) => {
      if (typeof item !== "object" || item === null) {
         throw Error("lines in the layoutLines array are not objects");
      }
      if (!("text" in item) || typeof item.text !== "string") {
         throw Error("layoutLines: text doesn't exist");
      }
      if (!("hasCursor" in item) || typeof item.hasCursor !== "boolean") {
         throw Error("layoutLines: hasCursor doesn't exist");
      }
      if (
         "cursorPos" in item &&
         (!Number.isInteger(item.cursorPos) || item.cursorPos < 0)
      ) {
         throw Error("layoutLines: cursorPos exist but is not a number");
      }
   });
   return lines as LayoutLine[];
}
export function validateEditorRenderInternals(internals: unknown) {
   if (typeof internals !== "object" || internals === null)
      throw Error("Editor: internals type is not an object");
   const internalsKeys = [
      "paddingX",
      "lastWidth",
      "scrollOffset",
      "autocompleteState",
      "autocompleteList",
      "layoutText",
      "segment",
   ];
   for (const key of internalsKeys) {
      if (!(key in internals)) {
         throw Error(`Editor: ${key} doesn't exist in Editor internals`);
      }
   }
   const keyedInternals = internals as EditorRenderInternals;

   if (
      !Number.isInteger(keyedInternals.paddingX) ||
      keyedInternals.paddingX < 0
   )
      throw Error("paddingX is not a number or is empty");
   if (
      !Number.isInteger(keyedInternals.scrollOffset) ||
      keyedInternals.scrollOffset < 0
   )
      throw Error("scrollOffset is not a number or is empty");
   if (
      !Number.isInteger(keyedInternals.lastWidth) ||
      keyedInternals.lastWidth <= 0
   )
      throw Error("lastWidth is not a number or is empty");
   if (typeof keyedInternals.layoutText !== "function")
      throw Error("layoutText is not a function");
   if (typeof keyedInternals.segment !== "function")
      throw Error("segment is not a function");

   return keyedInternals;
}
