import { Plugin } from "@opencode/plugin/tui";
import {
  createClipboard,
  createHostClipboard,
  createRendererClipboardAdapter,
} from "@opentui/core";
import { copyResponse } from "./copy-response";

export default Plugin.define({
  id: "message-copy",
  setup(context) {
    const controller = new AbortController();
    const clipboard = createClipboard({
      host: createHostClipboard(),
      terminal: createRendererClipboardAdapter(context.renderer),
    });
    let copying = false;

    context.keymap.layer(() => ({
      mode: "global",
      commands: [
        {
          id: "message-copy.pick",
          title: "Copy an agent response",
          palette: true,
          slash: { name: "copy-response" },
          enabled: () =>
            context.ui.router.current().type === "session" && !copying,
          async run() {
            if (copying) return;
            copying = true;
            try {
              await copyResponse(context, clipboard, controller.signal);
            } finally {
              copying = false;
            }
          },
        },
      ],
      bindings: ["message-copy.pick"],
    }));

    return () => {
      controller.abort();
      return clipboard.dispose();
    };
  },
});
