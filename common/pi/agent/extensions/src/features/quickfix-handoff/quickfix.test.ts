import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { createQuickfixHandoff } from "./quickfix.ts";

test("quickfix handoff renders verified locations as Nushell", async () => {
  const root = await mkdtemp(path.join(tmpdir(), "pi-quickfix-"));
  try {
    await mkdir(path.join(root, "src"));
    await writeFile(path.join(root, "src", "main.rs"), "first\nsecond\nthird\n");

    const handoff = await createQuickfixHandoff(root, [
      { path: "src/main.rs", line: 2, reason: "remove auth dispatch" },
      { path: "src/main.rs", line: 3, column: 4, reason: "remove auth helper" },
    ]);

    const source = path.join(root, "src", "main.rs");
    assert.equal(
      handoff.script,
      [
        "[",
        `  "${source}:2:1:remove auth dispatch",`,
        `  "${source}:3:4:remove auth helper"`,
        "] | str join (char nl) | nvim -q -",
      ].join("\n"),
    );
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("quickfix handoff rejects an unverified line", async () => {
  const root = await mkdtemp(path.join(tmpdir(), "pi-quickfix-"));
  try {
    await writeFile(path.join(root, "main.rs"), "only line\n");

    await assert.rejects(
      createQuickfixHandoff(root, [{ path: "main.rs", line: 2, reason: "missing" }]),
      /exceeds file length/,
    );
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
