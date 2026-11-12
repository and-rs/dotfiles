import stringWidth from "string-width";

const graphemeSegmenter = new Intl.Segmenter(undefined, {
  granularity: "grapheme",
});

export function graphemes(text: string): string[] {
  return Array.from(graphemeSegmenter.segment(text), (part) => part.segment);
}

function takePrefix(characters: string[], maxWidth: number): string {
  let width = 0;
  let end = 0;
  while (end < characters.length) {
    const characterWidth = stringWidth(characters[end] ?? "");
    if (width + characterWidth > maxWidth) break;
    width += characterWidth;
    end++;
  }
  return characters.slice(0, end).join("");
}

function takeSuffix(characters: string[], maxWidth: number): string {
  let width = 0;
  let start = characters.length;
  while (start > 0) {
    const characterWidth = stringWidth(characters[start - 1] ?? "");
    if (width + characterWidth > maxWidth) break;
    width += characterWidth;
    start--;
  }
  return characters.slice(start).join("");
}

function clipMiddle(text: string, maxWidth: number): string {
  const width = Math.max(1, maxWidth);
  if (stringWidth(text) <= width) return text;
  if (width === 1) return "…";

  const characters = graphemes(text);
  const remainingWidth = width - stringWidth("…");
  const leftWidth = Math.ceil(remainingWidth / 2);
  const rightWidth = remainingWidth - leftWidth;
  return `${takePrefix(characters, leftWidth)}…${takeSuffix(characters, rightWidth)}`;
}

export function compactPath(path: string, maxWidth: number): string {
  const width = Math.max(1, maxWidth);
  if (stringWidth(path) <= width) return path;

  const segments = path.split("/");
  if (segments.length <= 2) return clipMiddle(path, width);

  const first = segments[0] ?? "";
  const last = segments[segments.length - 1] ?? "";
  let prefix: string;
  if (first === "") {
    prefix = "/…/";
  } else {
    prefix = `${first}/…/`;
  }

  const prefixWidth = stringWidth(prefix);
  if (prefixWidth >= width) return clipMiddle(path, width);
  return `${prefix}${clipMiddle(last, width - prefixWidth)}`;
}
