import { Plugin } from "@opencode/plugin";
import { Rpc } from "@opencode/plugin/rpc";

interface GenerateInput {
  model: {
    providerID: string;
    id: string;
  };
  prompt: string;
}

const commitMessage = Rpc.define({
  id: "commit-message",
  methods: {
    generate: {
      input: {
        type: "object",
        properties: {
          model: {
            type: "object",
            properties: {
              providerID: { type: "string" },
              id: { type: "string" },
            },
            required: ["providerID", "id"],
            additionalProperties: false,
          },
          prompt: { type: "string" },
        },
        required: ["model", "prompt"],
        additionalProperties: false,
      },
      output: {
        type: "object",
        properties: { text: { type: "string" } },
        required: ["text"],
        additionalProperties: false,
      },
    },
  },
  events: {},
});

export default Plugin.define({
  id: "commit-message",
  async setup(ctx) {
    await ctx.rpc.register(commitMessage, {
      generate: async (input, { signal }) => {
        const { model, prompt } = input as GenerateInput;
        return ctx.generate.text({ model, prompt }, { signal });
      },
    });
  },
});
