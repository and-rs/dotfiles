import assert from "node:assert/strict";
import { describe, it } from "node:test";
import stringWidth from "string-width";
import { compactPath, graphemes } from "./text-width";

describe("compact path", () => {
  it("preserves graphemes when clipping a path", () => {
    const path = "/tmp/project/a👩‍💻bcdef";
    const compacted = compactPath(path, 9);

    assert.equal(compacted, "/…/a👩‍💻…ef");
    assert.ok(stringWidth(compacted) <= 9);
    assert.ok(graphemes(compacted).includes("👩‍💻"));
  });
});
