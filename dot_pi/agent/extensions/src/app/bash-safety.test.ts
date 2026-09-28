import assert from "node:assert/strict";
import test from "node:test";
import { isSafePlanBashCommand } from "./bash-safety.ts";

test("allows read-only exploration commands", () => {
  for (const command of [
    "pwd",
    "ls -la",
    "find . -name '*.ts'",
    "rg 'registerModes' src/app",
    "sed -n '1,40p' src/app/modes.ts",
    "git diff --stat",
    "git status --short",
  ]) {
    assert.equal(isSafePlanBashCommand(command), true, command);
  }
});

test("blocks shell composition and mutation", () => {
  for (const command of [
    "",
    "rm file",
    "git status && touch marker",
    "cat file > copy",
    "cat file | head",
    "$(touch marker)",
    "find . -exec rm {} \\",
    "find . -delete",
    "grep --pre=cat pattern file",
    "sed -i 's/a/b/' file",
    "git commit -am update",
    "git diff --output=patch",
  ]) {
    assert.equal(isSafePlanBashCommand(command), false, command);
  }
});
