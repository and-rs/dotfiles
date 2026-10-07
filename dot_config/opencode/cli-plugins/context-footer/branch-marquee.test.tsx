import assert from "node:assert/strict";
import { describe, it } from "node:test";
import stringWidth from "string-width";
import { branchMarqueeCycleLength, branchMarqueeFrame } from "./branch-marquee";

describe("branch marquee", () => {
  it("leaves branches that fit unchanged", () => {
    assert.equal(branchMarqueeFrame("main", 18, 5), "main");
  });

  it("scrolls through the branch and wraps across the separator", () => {
    const branch = "DAAS-46793/update-python-version";
    const width = 12;
    const cycleLength = branchMarqueeCycleLength(branch);
    const firstFrame = branchMarqueeFrame(branch, width, 0);
    const nextFrame = branchMarqueeFrame(branch, width, 1);
    const wrappedFrame = branchMarqueeFrame(branch, width, branch.length);

    assert.equal(firstFrame, "DAAS-46793/u");
    assert.equal(nextFrame, "AAS-46793/up");
    assert.equal(wrappedFrame.startsWith("   "), true);
    assert.equal(branchMarqueeFrame(branch, width, cycleLength), firstFrame);
  });

  it("keeps each frame within the available width, including graphemes", () => {
    const branch = "a👩‍💻b界c";
    const width = 3;
    const cycleLength = branchMarqueeCycleLength(branch);
    const frames = Array.from({ length: cycleLength }, (_, offset) =>
      branchMarqueeFrame(branch, width, offset),
    );

    assert.equal(frames[0], "a👩‍💻");
    assert.equal(frames[1], "👩‍💻b");
    for (const frame of frames) {
      assert.ok(stringWidth(frame) <= width);
    }
  });
});
