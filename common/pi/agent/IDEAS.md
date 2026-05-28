# Exoskeleton

## Ghost-Text Code Acceptance

### The Problem

AI coding agents generate code faster than humans can comprehend it. Once your
mental model of the codebase diverges from reality — even by one or two turns —
you end up approving things you don't fully understand and hoping it works.
Recovery is painful and slow.

### The Anti-Vibe-Coding Stance

Vibe coding is: prompt → click approve → repeat. You stop writing code.
Your fingers leave the keyboard. Your mental model of the codebase slowly
detaches from reality. You're managing an agent, not programming.

This approach takes the opposite position. The agent handles generation.
You handle every character that lands in the repo. Tedious by design.
Incredibly involved. You never stop typing actual code. Flow state survives
because the physical act of coding survives.

The friction is the feature. This isn't an autopilot. It's an exoskeleton.

### The Idea

Instead of the agent writing directly to files, all file mutations are queued as
pending diffs. The code only lands in the repo once the user physically types it
through ghost text — character by character, or line by line.

The act of typing is the review. There is no approve-all button.

### Why Typing Works

- You cannot skim something you are physically typing
- Every character passes through your brain before it lands
- Hesitation while typing is a signal: something looks wrong
- Muscle memory engagement increases retention compared to passive reading
- The bottleneck shifts from agent speed to human comprehension speed — intentionally

### How It Works

1. Agent calls `hashline-edit` or `file-create` as normal
2. Tool call is intercepted and blocked — Pi shows a pending change notification in the TUI
3. User triggers a keybind (same muscle memory as opening the Pi input editor)
4. Pi serializes the diff and sends it to Neovim via msgpack-rpc (`$NVIM` socket)
5. Neovim jumps to the exact file and line, renders the proposed lines as ghost text in-place
6. User types through the ghost text — character by character, in full file context
7a. Accept: user finishes typing the block — Pi fires the actual write, turn continues
7b. Reject: user hits a keybind to reject — Neovim closes the hunk, Pi injects a new user
    message into the session (optionally with a typed reason), agent retries from there
### Why Neovim Over Pi's TUI

Pi's TUI is a chat interface — ghost text there is detached from file context.
In Neovim the ghost text appears inside the real file with surrounding code,
Tree-sitter highlighting, and your own keybindings. That's where comprehension
actually happens.

### Acceptance Variants (weakest to strongest forcing)

- Tab per line — fast, still skimmable
- Type first N characters of each line — forces reading, reasonable speed
- Type one proof token per hunk (e.g. the function name being changed) — sweet spot
- Type the entire changed block — maximum comprehension, slow for large changes

Configurable per session or per turn size.

### Natural Scope Limiting

A turn that modifies 200 lines becomes genuinely painful to type through.
Users naturally push back by tightening prompts. Scope guard built in as friction,
not as a rule.

### Audit Trail

Each accepted block auto-commits with the user prompt as the commit message body.
`git log` becomes a comprehension trail. `git show HEAD` gives diff and reasoning.
Undoing a bad turn is `git reset HEAD~1`.

### Implementation

Two components:
- `exo-intercept` Pi extension — intercepts writes, speaks msgpack-rpc to `$NVIM`,
  blocks tool execution until Neovim signals acceptance
- `exoskeleton.nvim` — receives diffs, renders `virt_lines` via `nvim_buf_set_extmark`,
  tracks keystroke matching, signals back on hunk completion

IPC: Pi connects directly to Neovim's existing RPC socket via `$NVIM`. No dedicated
plugin socket needed — Pi calls nvim API directly, plugin only handles input logic.