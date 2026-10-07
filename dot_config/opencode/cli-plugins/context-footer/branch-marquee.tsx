import stringWidth from "string-width";
import { graphemes } from "./text-width";

const separator = "   ";

export function branchMarqueeCycleLength(branch: string): number {
  return graphemes(`${branch}${separator}`).length;
}

export function branchMarqueeFrame(
  branch: string,
  maxWidth: number,
  offset: number,
): string {
  const width = Math.max(1, maxWidth);
  if (stringWidth(branch) <= width) return branch;

  const characters = graphemes(`${branch}${separator}`);
  const start =
    ((offset % characters.length) + characters.length) % characters.length;
  let frame = "";
  let frameWidth = 0;

  for (let index = 0; index < characters.length; index++) {
    const character = characters[(start + index) % characters.length] ?? "";
    const characterWidth = stringWidth(character);
    if (frameWidth + characterWidth > width) break;
    frame += character;
    frameWidth += characterWidth;
  }

  if (frame) return frame;
  return "…";
}
