import { Plugin } from "@opencode/plugin/tui";

export default Plugin.define({
  id: "session-epilogue",
  setup(context) {
    // Install after renderer teardown; OpenTUI restores stdout during destroy.
    return () => {
      if (!context.renderer.isDestroyed) return;

      const output = process.stdout;
      const originalWrite = output.write;
      const patchedWrite = new Proxy(originalWrite, {
        apply(target, thisArg, args) {
          const chunk = args[0];
          if (typeof chunk === "string") {
            const lines = chunk.split("\n");
            const sessionLine = lines.findIndex((line) =>
              line.includes("Session"),
            );
            const continueLine = lines.findIndex(
              (line, index) =>
                index > sessionLine &&
                line.includes("Continue") &&
                line.includes("opencode -s "),
            );

            if (sessionLine > 0 && continueLine > sessionLine) {
              args[0] = lines.slice(sessionLine - 1).join("\n");
              if (output.write === patchedWrite) output.write = originalWrite;
            }
          }
          return Reflect.apply(target, thisArg, args);
        },
      });

      output.write = patchedWrite;
    };
  },
});
