import { access, mkdir, writeFile } from "node:fs/promises";
import { dirname, isAbsolute, relative, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { renderDeltaDiff } from "../delta-diff.ts";
import { Type } from "typebox";
type CreateFileParams = {
  path: string;
  content: string;
};

function isInsideCwd(cwd: string, value: string): boolean {
  const absolute = resolve(cwd, value);
  const rel = relative(cwd, absolute);
  return rel.length === 0 || (!rel.startsWith("..") && !isAbsolute(rel));
}

function resolveCreatablePath(cwd: string, value: string): string {
  if (!isInsideCwd(cwd, value)) {
    throw new Error(`Path must be inside cwd: ${value}`);
  }
  return resolve(cwd, value);
}

async function pathExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

export default function registerFileCreateFeature(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "file-create",
    label: "File Create",
    description: "Create new text file. Refuses overwrite existing files. Returns diff.",
    promptSnippet: "Create new files with file-create.",
    parameters: Type.Object({
      path: Type.String({ description: "Path to new file. Must be inside cwd." }),
      content: Type.String({ description: "Complete UTF-8 file content." }),
    }),
    execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
      const args = params as CreateFileParams;
      const absolutePath = resolveCreatablePath(ctx.cwd, args.path);
      return withFileMutationQueue(absolutePath, async () => {
        if (await pathExists(absolutePath)) {
          throw new Error(`File already exists: ${args.path}. Use anchorline-edit for existing files.`);
        }
        await mkdir(dirname(absolutePath), { recursive: true });
        await writeFile(absolutePath, args.content, "utf8");
        const diff = await renderDeltaDiff(ctx.cwd, args.path, "", args.content);
        return { content: [{ type: "text", text: diff }], details: { path: args.path, diff } };
      });
    },
    renderResult(result, _options, _theme) {
      const diff = result.content.find((item) => item.type === "text")?.text ?? "";
      return new Text(diff, 0, 0);
    },
  });
}
