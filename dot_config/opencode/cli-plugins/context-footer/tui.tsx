import { Plugin } from "@opencode/plugin/tui";

export default Plugin.define({
  id: "context-footer",
  setup(context) {
    context.ui.slot({
      append: "prompt.footer.status",
      render: ({ sessionID }) => {
        let session: ReturnType<typeof context.data.session.get>;
        if (sessionID) session = context.data.session.get(sessionID);

        const selected = context.ui.model.current();
        const location = context.location ?? context.data.location.default();
        let contextWindow: number | undefined;

        if (selected) {
          const model = context.data.location.model
            .list(location)
            ?.find(
              (entry) =>
                entry.providerID === selected.providerID &&
                entry.id === selected.modelID,
            );
          contextWindow = model?.limit.context;
        }

        let window: string;
        if (contextWindow) {
          window = new Intl.NumberFormat("en", {
            notation: "compact",
            maximumFractionDigits: 1,
          }).format(contextWindow);
        } else {
          window = "No max. tokens found";
        }

        return <text fg={context.theme.text.muted}>{`Σ · ${window}`}</text>;
      },
    });
  },
});
