import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import {
  buildNvimArgs,
  buildOpenQuickfixExpression,
  buildSetQuickfixExpression,
  prepareQuickfix,
} from "../plugin/quickfix.ts";

async function withFixture(run: (root: string) => Promise<void>): Promise<void> {
  const root = await mkdtemp(path.join(tmpdir(), "opencode-quickfix-"));
  try {
    await mkdir(path.join(root, "src"));
    await writeFile(path.join(root, "src", "main.ts"), "first\nsecond\nthird\n");
    await run(root);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

test("prepares canonical quickfix entries and validates lines", async () => {
  await withFixture(async (root) => {
    const prepared = await prepareQuickfix(
      { directory: path.join(root, "src"), worktree: root },
      [{ path: "main.ts", line: 2, column: 4, reason: "inspect dispatch" }],
    );

    assert.deepEqual(prepared.entries, [
      {
        filename: path.join(root, "src", "main.ts"),
        lnum: 2,
        col: 4,
        text: "inspect dispatch",
      },
    ]);
    assert.deepEqual(prepared.paths, ["src/main.ts"]);
  });
});

test("rejects lines and symlinks outside the worktree", async () => {
  await withFixture(async (root) => {
    await assert.rejects(
      prepareQuickfix(
        { directory: root, worktree: root },
        [{ path: "src/main.ts", line: 8, reason: "missing" }],
      ),
      /exceeds file length/,
    );

    const outside = await mkdtemp(path.join(tmpdir(), "opencode-outside-"));
    try {
      const outsideFile = path.join(outside, "secret.ts");
      await writeFile(outsideFile, "secret\n");
      await symlink(outsideFile, path.join(root, "src", "outside.ts"));

      await assert.rejects(
        prepareQuickfix(
          { directory: root, worktree: root },
          [{ path: "src/outside.ts", line: 1, reason: "blocked" }],
        ),
        /inside the worktree/,
      );
    } finally {
      await rm(outside, { recursive: true, force: true });
    }
  });
});

test("builds shell-free remote expressions for special text", () => {
  const entries = [
    {
      filename: "/work/file.ts",
      lnum: 1,
      col: 1,
      text: "don't run\nanything",
    },
  ];
  const expression = buildSetQuickfixExpression(entries);

  assert.match(expression, /''/);
  assert.doesNotMatch(expression, /\n/);
  assert.equal(buildOpenQuickfixExpression(), "execute('cfirst | copen | wincmd p')");
  assert.deepEqual(buildNvimArgs("/tmp/nvim.sock; touch /tmp/nope", expression), [
    "--server",
    "/tmp/nvim.sock; touch /tmp/nope",
    "--remote-expr",
    expression,
  ]);
});

test("does not require reading or writing a command script", async () => {
  await withFixture(async (root) => {
    const before = await readFile(path.join(root, "src", "main.ts"), "utf8");
    await prepareQuickfix(
      { directory: root, worktree: root },
      [{ path: "src/main.ts", line: 1, reason: "review" }],
    );
    assert.equal(await readFile(path.join(root, "src", "main.ts"), "utf8"), before);
  });
});
