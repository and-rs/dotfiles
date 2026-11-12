import { readFile } from "node:fs/promises";
import { Plugin } from "@opencode/plugin";
import { Rpc } from "@opencode/plugin/rpc";

type GenerateInput = {
  model: {
    providerID: string;
    id: string;
  };
} & ({ prompt: string } | { promptFile: string });

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
          promptFile: { type: "string" },
        },
        required: ["model"],
        oneOf: [{ required: ["prompt"] }, { required: ["promptFile"] }],
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
        const request = input as GenerateInput;
        let prompt: string;
        if ("promptFile" in request) {
          prompt = await readFile(request.promptFile, {
            encoding: "utf8",
            signal,
          });
        } else {
          prompt = request.prompt;
        }
        return ctx.generate.text({ model: request.model, prompt }, { signal });
      },
    });
  },
});
