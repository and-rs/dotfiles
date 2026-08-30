import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { formatCodeView, readCodeView } from "./read.ts";

test("code-view returns the requested numbered range", async () => {
  const root = await mkdtemp(path.join(tmpdir(), "pi-code-view-"));
  try {
    await mkdir(path.join(root, "src"));
    await writeFile(path.join(root, "src", "sample.ts"), "first\nsecond\nthird\nfourth\n");

    const result = await readCodeView(root, "src/sample.ts", 2, 3);

    assert.deepEqual(result.lines, [
      { number: 2, text: "second" },
      { number: 3, text: "third" },
    ]);
    assert.equal(formatCodeView(result), "code-view src/sample.ts · lines 2-3 of 4\n2: second\n3: third");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("code-view rejects paths that escape through a symlink", async () => {
  const root = await mkdtemp(path.join(tmpdir(), "pi-code-view-"));
  const outside = await mkdtemp(path.join(tmpdir(), "pi-code-view-outside-"));
  try {
    await writeFile(path.join(outside, "secret.ts"), "secret");
    await symlink(outside, path.join(root, "linked"));

    await assert.rejects(
      readCodeView(root, "linked/secret.ts"),
      /resolves outside cwd/,
    );
  } finally {
    await rm(root, { recursive: true, force: true });
    await rm(outside, { recursive: true, force: true });
  }
});
