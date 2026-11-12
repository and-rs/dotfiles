import type { Context } from "@opencode/plugin/tui/context";
import type {
  OptimizedBuffer,
  Renderable,
  TextRenderable,
} from "@opentui/core";

// OpenTUI's public BOLD and UNDERLINE bits. Do not import its runtime here:
// the host can use a different OpenTUI version than this config's dependencies.
const FOCUS_ATTRIBUTES = 1 | (1 << 3);

type Forms = Context["data"]["session"]["form"];
type Form = NonNullable<ReturnType<Forms["list"]>>[number];
type FocusContext = {
  renderer: Context["renderer"];
  data: {
    session: Pick<Context["data"]["session"], "family"> & {
      form: Pick<Forms, "list">;
    };
  };
  ui: { router: Pick<Context["ui"]["router"], "current"> };
  keymap: { mode: Pick<Context["keymap"]["mode"], "current"> };
  theme: {
    text: {
      muted: Context["theme"]["text"]["muted"];
      formfield: Pick<Context["theme"]["text"]["formfield"], "focused">;
    };
  };
};

function* visibleTree(node: Renderable): Generator<Renderable> {
  if (node.isDestroyed || !node.visible || node.opacity === 0) return;
  yield node;
  for (const child of node.getChildren()) yield* visibleTree(child);
}

function isText(node: Renderable | undefined): node is TextRenderable {
  return node !== undefined && "plainText" in node && "fg" in node;
}

function matchesOption(form: Form, label: string, index: number): boolean {
  return form.fields.some((field) => {
    if (field.type !== "string" && field.type !== "multiselect") return false;
    const options = field.options ?? [];
    if (options[index]?.label === label) return true;
    return (
      field.custom === true &&
      index === options.length &&
      label === "Type your own answer"
    );
  });
}

function focusedLabel(
  root: Renderable,
  form: Form,
  text: FocusContext["theme"]["text"],
): TextRenderable | undefined {
  // OpenCode 2.2.5 has no question-row IDs or styling slot. Match its form
  // heading, left border, numbered-row structure, and server-provided labels.
  // If that structure changes, leave the UI untouched.
  for (const body of visibleTree(root)) {
    const panel = body.parent;
    if (!panel || !("border" in panel)) continue;
    if (!Array.isArray(panel.border) || panel.border.join() !== "left")
      continue;
    const heading = body.getChildren()[0]?.getChildren()[0];
    if (!isText(heading) || heading.plainText !== form.title) continue;

    for (const label of visibleTree(body)) {
      if (!isText(label) || !label.fg.equals(text.formfield.focused)) continue;
      const line = label.parent?.parent;
      const children = line?.getChildren();
      if (children?.[1] !== label.parent) continue;
      const number = children[0]?.getChildren()[0];
      if (!isText(number)) continue;
      if (!/^[1-9]\d*\.$/.test(number.plainText)) continue;
      if (!number.fg.equals(text.formfield.focused)) continue;
      const index = Number(number.plainText.slice(0, -1)) - 1;
      if (matchesOption(form, label.plainText, index)) return label;
    }
  }
}

function emphasizeLabel(buffer: OptimizedBuffer, label: TextRenderable) {
  const left = Math.max(0, Math.floor(label.screenX));
  const top = Math.max(0, Math.floor(label.screenY));
  const right = Math.min(buffer.width, Math.ceil(label.screenX + label.width));
  const bottom = Math.min(
    buffer.height,
    Math.ceil(label.screenY + label.height),
  );
  const attributes = buffer.buffers.attributes;
  for (let y = top; y < bottom; y++) {
    for (let x = left; x < right; x++) {
      const index = y * buffer.width + x;
      attributes[index] = (attributes[index] ?? 0) | FOCUS_ATTRIBUTES;
    }
  }
}

export function installQuestionFocus(context: FocusContext): () => void {
  const { renderer } = context;
  const paint = (buffer: OptimizedBuffer) => {
    const route = context.ui.router.current();
    if (route.type !== "session" || context.keymap.mode.current() !== "form")
      return;
    const { text } = context.theme;
    if (text.formfield.focused.equals(text.muted)) return;
    const sessions = context.data.session.family(route.sessionID);
    for (const sessionID of sessions) {
      for (const form of context.data.session.form.list(sessionID) ?? []) {
        if (form.metadata?.kind !== "question") continue;
        const label = focusedLabel(renderer.root, form, text);
        if (label) {
          emphasizeLabel(buffer, label);
          return;
        }
      }
    }
  };

  // Only the freshly rendered frame changes; host renderables and theme stay intact.
  renderer.addPostProcessFn(paint);
  renderer.root.requestRender();
  return () => {
    renderer.removePostProcessFn(paint);
    if (!renderer.isDestroyed) renderer.root.requestRender();
  };
}
