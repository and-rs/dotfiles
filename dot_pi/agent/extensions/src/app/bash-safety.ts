const READ_ONLY_COMMANDS = new Set([
  "cat",
  "file",
  "find",
  "grep",
  "head",
  "ls",
  "rg",
  "stat",
  "tail",
  "wc",
]);

const SAFE_GIT_COMMANDS = new Set([
  "diff",
  "grep",
  "log",
  "ls-files",
  "rev-parse",
  "show",
  "status",
]);

const SHELL_OPERATORS = new Set([
  "&",
  "|",
  ";",
  "<",
  ">",
  "(",
  ")",
  "$",
  "`",
  "\\",
  "#",
]);
const FIND_WRITE_ACTIONS = new Set([
  "-delete",
  "-exec",
  "-execdir",
  "-fls",
  "-fprint",
  "-fprint0",
  "-fprintf",
  "-ok",
  "-okdir",
]);
const UNSAFE_GIT_OPTIONS = new Set([
  "--exec-path",
  "--ext-diff",
  "--open-files-in-pager",
  "--output",
  "--pager",
  "--textconv",
]);
const PRINT_ONLY_SED_SCRIPT = /^(?:\d+|\$)?(?:,(?:\d+|\$))?p$/;

function tokenizeSimpleCommand(command: string): string[] | undefined {
  if (
    command.includes("\n") ||
    command.includes("\r") ||
    command.includes("\0")
  ) {
    return undefined;
  }

  const args: string[] = [];
  let token = "";
  let tokenStarted = false;
  let quote: "'" | '"' | undefined;

  function pushToken(): void {
    if (!tokenStarted) return;
    args.push(token);
    token = "";
    tokenStarted = false;
  }

  for (const char of command) {
    if (quote === "'") {
      if (char === "'") {
        quote = undefined;
      } else {
        token += char;
      }
      continue;
    }

    if (quote === '"') {
      if (char === '"') {
        quote = undefined;
        continue;
      }
      if (char === "$" || char === "`" || char === "\\") return undefined;
      token += char;
      continue;
    }

    if (char === "'" || char === '"') {
      quote = char;
      tokenStarted = true;
      continue;
    }
    if (SHELL_OPERATORS.has(char)) return undefined;
    if (/\s/.test(char)) {
      pushToken();
      continue;
    }
    token += char;
    tokenStarted = true;
  }

  if (quote) return undefined;
  pushToken();
  if (args.length === 0) return undefined;
  return args;
}

function hasWriteAction(args: string[]): boolean {
  return args.some((arg) => {
    if (FIND_WRITE_ACTIONS.has(arg)) return true;
    if (arg.startsWith("-fprint=") || arg.startsWith("-fprintf=")) return true;
    return false;
  });
}

function hasUnsafeSearchOption(args: string[]): boolean {
  return args.some((arg) => arg === "--pre" || arg.startsWith("--pre="));
}

function isSafeGitCommand(args: string[]): boolean {
  const subcommand = args[0];
  if (!subcommand || !SAFE_GIT_COMMANDS.has(subcommand)) return false;

  for (const arg of args.slice(1)) {
    const optionName = arg.split("=", 1)[0] ?? arg;
    if (UNSAFE_GIT_OPTIONS.has(optionName)) return false;
  }
  if (subcommand === "grep" && args.includes("--open-files-in-pager")) {
    return false;
  }
  return true;
}

function isSafeSedCommand(args: string[]): boolean {
  if (args.length < 3 || args[0] !== "-n") return false;
  if (!PRINT_ONLY_SED_SCRIPT.test(args[1] ?? "")) return false;
  return args.slice(2).every((arg) => !arg.startsWith("-") && arg !== "-");
}

export function isSafePlanBashCommand(command: unknown): boolean {
  if (typeof command !== "string") return false;
  const args = tokenizeSimpleCommand(command);
  if (!args) return false;

  const [program, ...commandArgs] = args;
  if (!program) return false;
  if (program === "pwd") return commandArgs.length === 0;
  if (program === "git") return isSafeGitCommand(commandArgs);
  if (program === "find") return !hasWriteAction(commandArgs);
  if (program === "grep") {
    return commandArgs.length >= 2 && !hasUnsafeSearchOption(commandArgs);
  }
  if (program === "rg") {
    return commandArgs.length >= 1 && !hasUnsafeSearchOption(commandArgs);
  }
  if (program === "sed") return isSafeSedCommand(commandArgs);
  if (!READ_ONLY_COMMANDS.has(program)) return false;

  if (["cat", "file", "head", "stat", "tail", "wc"].includes(program)) {
    return commandArgs.some((arg) => !arg.startsWith("-"));
  }
  return true;
}
