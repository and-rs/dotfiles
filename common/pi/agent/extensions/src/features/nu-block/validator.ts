import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";

export interface NuIssue {
  rule: string;
  message: string;
  line?: number;
  column?: number;
  suggestion?: string;
}

export interface NuValidationOk {
  status: "ok";
  purpose: string;
  formattedScript: string;
  output: string;
}

export interface NuValidationInvalid {
  status: "invalid";
  purpose: string;
  issues: NuIssue[];
}

export type NuValidationResult = NuValidationOk | NuValidationInvalid;

interface CommandResult {
  code: number;
  stdout: string;
  stderr: string;
}

interface NuDiagnostic {
  type?: string;
  severity?: string;
  message?: string;
  span?: {
    start?: number;
  };
}

const DEFAULT_PURPOSE = "Run in Nushell.";

export async function validateNuBlock(purposeInput: string, scriptInput: string): Promise<NuValidationResult> {
  const purpose = sanitizePurpose(purposeInput);
  const script = normalizeScript(scriptInput);
  const issues = uniqueIssues([...lintNuScript(script), ...(await checkNuSyntax(script))]);
  if (issues.length > 0) return { status: "invalid", purpose, issues };
  const formattedScript = await formatWithTopiary(script);
  const formattedIssues = uniqueIssues([...lintNuScript(formattedScript), ...(await checkNuSyntax(formattedScript))]);
  if (formattedIssues.length > 0) return { status: "invalid", purpose, issues: formattedIssues };
  return {
    status: "ok",
    purpose,
    formattedScript,
    output: `${purpose}\n\`\`\`nu\n${formattedScript}\n\`\`\``,
  };
}

function sanitizePurpose(purpose: string): string {
  const cleaned = purpose.replace(/\s+/g, " ").trim();
  return cleaned || DEFAULT_PURPOSE;
}

function normalizeScript(script: string): string {
  return script.replace(/\r\n/g, "\n").trim();
}

function formatIssue(issue: NuIssue): string {
  const location = issue.line ? ` line ${issue.line}${issue.column ? `:${issue.column}` : ""}` : "";
  const suggestion = issue.suggestion ? ` Fix: ${issue.suggestion}` : "";
  return `- ${issue.rule}${location}: ${issue.message}${suggestion}`;
}

function uniqueIssues(issues: NuIssue[]): NuIssue[] {
  const seen = new Set<string>();
  const deduped: NuIssue[] = [];
  for (const issue of issues) {
    const key = `${issue.rule}:${issue.line ?? 0}:${issue.column ?? 0}:${issue.message}`;
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(issue);
  }
  return deduped;
}

function lintNuScript(script: string): NuIssue[] {
  const issues: NuIssue[] = [];
  if (!script) {
    issues.push({
      rule: "copy-paste-safe",
      message: "Script is empty.",
      suggestion: "Pass runnable Nushell only.",
    });
    return issues;
  }
  if (script.includes("```")) {
    issues.push({
      rule: "copy-paste-safe",
      message: "Script must not include Markdown fences.",
      suggestion: "Pass raw Nushell without ``` fences.",
    });
  }
  if (/^\s*(?:\$|>)\s/m.test(script)) {
    issues.push({
      rule: "copy-paste-safe",
      message: "Prompt characters make output non-runnable.",
      suggestion: "Remove leading $ or > prompts.",
    });
  }
  if (/\.\.\.|…/.test(script)) {
    issues.push({
      rule: "copy-paste-safe",
      message: "Ellipsis makes output non-runnable.",
      suggestion: "Pass complete Nushell, not abbreviated text.",
    });
  }
  if (/`/.test(script)) {
    issues.push({
      rule: "no-backticks",
      message: "Nushell never uses PowerShell-style backtick continuation.",
      suggestion: "Use wrapped `( )` form for multiline externals or pipelines.",
    });
  }
  if (/\\\s*$/m.test(script)) {
    issues.push({
      rule: "no-bash-continuation",
      message: "Bash-style trailing backslash continuation is forbidden.",
      suggestion: "Use wrapped `( )` form instead.",
    });
  }
  if (/&&|\|\|/.test(script)) {
    issues.push({
      rule: "no-bashisms",
      message: "Use Nushell pipelines or control flow, not && or ||.",
      suggestion: "Rewrite with Nushell syntax.",
    });
  }
  if (/\$\(/.test(script)) {
    issues.push({
      rule: "no-bashisms",
      message: "Use `(expr)` instead of $().",
      suggestion: "Rewrite command substitution with Nushell expression syntax.",
    });
  }
  if (/\bexport\s+[A-Za-z_][A-Za-z0-9_]*=/.test(script)) {
    issues.push({
      rule: "no-bashisms",
      message: "Use $env.NAME = value instead of export NAME=value.",
      suggestion: "Rewrite environment assignment in Nushell form.",
    });
  }
  if (/\[\[/.test(script)) {
    issues.push({
      rule: "no-bashisms",
      message: "[[ ]] is Bash syntax, not Nushell.",
      suggestion: "Rewrite with Nushell condition syntax.",
    });
  }
  if (/(^|\s|\b)\^/.test(script) && !/"[^"]*\^[^"]*"|'[^']*\^[^']*'/.test(script)) {
    issues.push({
      rule: "no-stray-hat",
      message: "Avoid ^ in user-facing Nushell unless absolutely required.",
      suggestion: "Call external command directly without ^.",
    });
  }
  issues.push(...lintWrappedMultiline(script));
  return issues;
}

function lintWrappedMultiline(script: string): NuIssue[] {
  const issues: NuIssue[] = [];
  const lines = script.split("\n");
  let parenDepth = 0;
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index] ?? "";
    const trimmed = line.trim();
    const depthBefore = parenDepth;
    if (trimmed && !trimmed.startsWith("#") && depthBefore === 0) {
      const column = line.indexOf(trimmed) + 1;
      if (/^--?[A-Za-z0-9]/.test(trimmed)) {
        issues.push({
          rule: "multiline-wrapped",
          line: index + 1,
          column,
          message: "Flag line outside wrapped `( )` form.",
          suggestion: "Wrap multiline external command in `( )` and keep flags inside block.",
        });
      } else if (trimmed.startsWith("|")) {
        issues.push({
          rule: "multiline-wrapped",
          line: index + 1,
          column,
          message: "Pipe continuation outside wrapped `( )` form.",
          suggestion: "Wrap whole multiline pipeline in `( )`.",
        });
      }
    }
    parenDepth = Math.max(0, parenDepth + parenDelta(line));
  }
  return issues;
}

function parenDelta(line: string): number {
  let delta = 0;
  let inString = false;
  let stringChar = '';
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if ((char === '"' || char === "'") && line[i - 1] !== "\\") {
      if (!inString) {
        inString = true;
        stringChar = char;
      } else if (char === stringChar) {
        inString = false;
      }
    } else if (!inString) {
      if (char === "#") break;
      if (char === "(") delta += 1;
      else if (char === ")") delta -= 1;
    }
  }
  return delta;
}

async function checkNuSyntax(script: string): Promise<NuIssue[]> {
  const output = await withTempNuFile(script, async (filePath) => runCommand("nu", ["--ide-check", "10", filePath]));
  if (output.code !== 0 && output.stdout.trim().length === 0) {
    throw new Error(output.stderr.trim() || "nu --ide-check failed");
  }
  const issues: NuIssue[] = [];
  for (const line of output.stdout.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    let diagnostic: NuDiagnostic;
    try {
      diagnostic = JSON.parse(trimmed) as NuDiagnostic;
    } catch {
      continue;
    }
    if (diagnostic.type !== "diagnostic" || !diagnostic.message) continue;
    const point = offsetToLineColumn(script, diagnostic.span?.start ?? 0);
    const severity = diagnostic.severity && diagnostic.severity !== "Error" ? `${diagnostic.severity}: ` : "";
    issues.push({
      rule: "syntax",
      line: point.line,
      column: point.column,
      message: `${severity}${diagnostic.message}`,
    });
  }
  return issues;
}

function offsetToLineColumn(text: string, offset: number): { line: number; column: number } {
  const limit = Math.max(0, Math.min(offset, text.length));
  let line = 1;
  let column = 1;
  for (let index = 0; index < limit; index++) {
    if (text[index] === "\n") {
      line += 1;
      column = 1;
      continue;
    }
    column += 1;
  }
  return { line, column };
}

async function formatWithTopiary(script: string): Promise<string> {
  return withTempNuFile(script, async (filePath) => {
    const env = await resolveTopiaryEnv();
    const result = await runCommand("topiary", ["format", filePath], { env });
    if (result.code !== 0) throw new Error(result.stderr.trim() || "topiary format failed");
    return (await readFile(filePath, "utf8")).trimEnd();
  });
}

async function resolveTopiaryEnv(): Promise<NodeJS.ProcessEnv> {
  const env: NodeJS.ProcessEnv = {};
  const scriptDir = fileURLToPath(new URL(".", import.meta.url));
  const rootDir = resolve(scriptDir, "../../../../../../");
  const configPath = resolve(rootDir, "topiary/languages.ncl");
  if (await pathExists(configPath)) env.TOPIARY_CONFIG_FILE = configPath;
  const languageDir = resolve(rootDir, "topiary/queries");
  if (await pathExists(languageDir)) env.TOPIARY_LANGUAGE_DIR = languageDir;
  return env;
}

async function pathExists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

async function withTempNuFile<T>(script: string, action: (filePath: string) => Promise<T>): Promise<T> {
  const dir = await mkdtemp(join(tmpdir(), "pi-nu-block-"));
  const filePath = join(dir, "block.nu");
  await writeFile(filePath, script, "utf8");
  try {
    return await action(filePath);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

async function runCommand(
  command: string,
  args: string[],
  options: { cwd?: string; env?: NodeJS.ProcessEnv } = {},
): Promise<CommandResult> {
  try {
    return await new Promise<CommandResult>((resolveResult, reject) => {
      const child = spawn(command, args, {
        cwd: options.cwd,
        env: { ...process.env, ...options.env },
        stdio: ["ignore", "pipe", "pipe"],
        timeout: 10000,
      });
      let stdout = "";
      let stderr = "";
      child.stdout.on("data", (chunk) => {
        stdout += String(chunk);
      });
      child.stderr.on("data", (chunk) => {
        stderr += String(chunk);
      });
      child.on("error", reject);
      child.on("close", (code) => {
        resolveResult({ code: code ?? 1, stdout, stderr });
      });
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`emit-nu-block tool error: ${message}`);
  }
}
