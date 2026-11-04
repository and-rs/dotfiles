import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  BoxRenderable,
  RGBA,
  TextAttributes,
  TextRenderable,
} from "@opentui/core";
import { createTestRenderer } from "@opentui/core/testing";
import { installQuestionFocus } from "./highlight";

type FocusContext = Parameters<typeof installQuestionFocus>[0];
type Form = NonNullable<
  ReturnType<FocusContext["data"]["session"]["form"]["list"]>
>[number];

async function harness(dark = false, multi = false) {
  const test = await createTestRenderer({ width: 48, height: 18 });
  const { renderer } = test;
  let background = "#fafafa";
  let focused = "#00368a";
  let muted = "#5c5c5c";
  if (dark) {
    background = "#0a1520";
    focused = "#b2ffff";
    muted = "#79e8f4";
  }
  const focusColor = RGBA.fromHex(focused);
  const mutedColor = RGBA.fromHex(muted);
  const options = [
    { value: "alpha", label: "Alpha", description: "Alpha description" },
    { value: "beta", label: "Beta", description: "Beta description" },
  ];
  const form: Form = {
    id: "question",
    sessionID: "current",
    title: "Questions",
    metadata: { kind: "question" },
    fields: [{ key: "q0", type: "string", options, custom: true }],
  };
  if (multi) {
    form.fields[0] = { key: "q0", type: "multiselect", options, custom: true };
  }
  const state = {
    forms: [form],
    mode: "form",
    route: { type: "session", sessionID: "current" } as ReturnType<
      FocusContext["ui"]["router"]["current"]
    >,
  };
  const transcript = new TextRenderable(renderer, {
    content: "Questions — Alpha — Beta",
    fg: focusColor,
  });
  renderer.root.add(transcript);
  const panel = new BoxRenderable(renderer, {
    border: ["left"],
    backgroundColor: background,
  });
  renderer.root.add(panel);
  const body = new BoxRenderable(renderer, { padding: 1 });
  panel.add(body);
  const heading = new BoxRenderable(renderer, { paddingLeft: 1 });
  body.add(heading);
  heading.add(
    new TextRenderable(renderer, { content: form.title, fg: mutedColor }),
  );
  const choices = new BoxRenderable(renderer, {});
  body.add(choices);
  const rows = [
    ...options,
    { label: "Type your own answer", description: "" },
  ].map((option, index) => {
    const row = new BoxRenderable(renderer, {});
    choices.add(row);
    const line = new BoxRenderable(renderer, { flexDirection: "row" });
    row.add(line);
    const numberBox = new BoxRenderable(renderer, {
      backgroundColor: background,
      paddingRight: 1,
    });
    line.add(numberBox);
    const number = new TextRenderable(renderer, {
      content: `${index + 1}.`,
      fg: mutedColor,
    });
    numberBox.add(number);
    const labelBox = new BoxRenderable(renderer, {
      backgroundColor: background,
      flexDirection: "row",
    });
    line.add(labelBox);
    if (multi) {
      labelBox.add(
        new TextRenderable(renderer, {
          content: "[✓] ",
          fg: focusColor,
        }),
      );
    }
    const label = new TextRenderable(renderer, {
      content: option.label,
      fg: mutedColor,
    });
    labelBox.add(label);
    if (!multi) {
      line.add(new TextRenderable(renderer, { content: " ✓", fg: focusColor }));
    }
    if (option.description) {
      row.add(
        new TextRenderable(renderer, {
          content: option.description,
          fg: mutedColor,
        }),
      );
    }
    return { label, number };
  });
  function focus(index: number) {
    rows.forEach((row, i) => {
      let color = mutedColor;
      if (i === index) color = focusColor;
      row.label.fg = color;
      row.number.fg = color;
    });
  }
  focus(0);
  const context: FocusContext = {
    renderer,
    data: {
      session: {
        family: () => ["current"],
        form: { list: () => state.forms },
      },
    },
    ui: { router: { current: () => state.route } },
    keymap: { mode: { current: () => state.mode } },
    theme: {
      text: { muted: mutedColor, formfield: { focused: focusColor } },
    },
  };
  const stop = installQuestionFocus(context);
  function highlightedText() {
    const spans = test.captureSpans().lines.flatMap((line) => line.spans);
    assert.ok(
      spans.every((span) => (span.attributes & TextAttributes.INVERSE) === 0),
      "Labels must not be inverted",
    );
    const emphasis = TextAttributes.BOLD | TextAttributes.UNDERLINE;
    const highlighted = spans.filter(
      (span) => (span.attributes & emphasis) !== 0,
    );
    assert.ok(
      highlighted.every((span) => (span.attributes & emphasis) === emphasis),
      "Highlighted spans must have both bold and underline",
    );
    return highlighted.map((span) => span.text.trim()).filter(Boolean);
  }
  return {
    ...test,
    state,
    form,
    rows,
    panel,
    context,
    focus,
    highlightedText,
    stop,
    destroy() {
      stop();
      renderer.destroy();
    },
  };
}

describe("question focus emphasis", () => {
  for (const dark of [false, true]) {
    it(`bolds and underlines only the focused label; follows focus and restores on unload (dark=${dark})`, async () => {
      const test = await harness(dark);
      try {
        await test.renderOnce();
        assert.deepEqual(test.highlightedText(), ["Alpha"]);
        assert.equal(test.rows[0]?.label.attributes, TextAttributes.NONE);
        test.focus(1);
        await test.renderOnce();
        assert.deepEqual(test.highlightedText(), ["Beta"]);
        test.focus(2);
        await test.renderOnce();
        assert.deepEqual(test.highlightedText(), ["Type your own answer"]);
        test.stop();
        await test.renderOnce();
        assert.deepEqual(test.highlightedText(), []);
      } finally {
        test.destroy();
      }
    });
  }

  it("does not mistake selected checkmarks for keyboard focus in multiselect", async () => {
    const test = await harness(false, true);
    try {
      await test.renderOnce();
      assert.deepEqual(test.highlightedText(), ["Alpha"]);
      test.focus(1);
      await test.renderOnce();
      assert.deepEqual(test.highlightedText(), ["Beta"]);
    } finally {
      test.destroy();
    }
  });

  it("clears when the form closes, a modal owns input, or the route changes", async () => {
    const test = await harness();
    try {
      await test.renderOnce();
      assert.deepEqual(test.highlightedText(), ["Alpha"]);
      test.state.forms = [];
      await test.renderOnce();
      assert.deepEqual(test.highlightedText(), []);
      test.state.forms = [test.form];
      test.state.mode = "modal";
      await test.renderOnce();
      assert.deepEqual(test.highlightedText(), []);
      test.state.mode = "form";
      test.state.route = { type: "home" };
      await test.renderOnce();
      assert.deepEqual(test.highlightedText(), []);
    } finally {
      test.destroy();
    }
  });

  it("leaves non-question forms, hidden panels, and unknown layouts untouched", async () => {
    const test = await harness();
    try {
      test.form.metadata = { kind: "auth" };
      await test.renderOnce();
      assert.deepEqual(test.highlightedText(), []);
      test.form.metadata = { kind: "question" };
      test.panel.visible = false;
      await test.renderOnce();
      assert.deepEqual(test.highlightedText(), []);
      test.panel.visible = true;
      test.panel.border = true;
      await test.renderOnce();
      assert.deepEqual(test.highlightedText(), []);
    } finally {
      test.destroy();
    }
  });

  it("fails closed if the theme gives focused and inactive numbers the same color", async () => {
    const test = await harness();
    try {
      test.context.theme.text.formfield = {
        focused: test.context.theme.text.muted,
      };
      await test.renderOnce();
      assert.deepEqual(test.highlightedText(), []);
    } finally {
      test.destroy();
    }
  });
});
