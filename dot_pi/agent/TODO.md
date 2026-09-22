# pi agent todo

## tools

- [x] drop custom explore kit (code-overview, code-search, code-files, code-view)
- [x] drop quickfix-handoff
- [x] teach/plan: read, grep, find, ls, read-image, web_search, web_fetch
- [x] build adds: bash, edit, write
- [x] mode tool gate: setActiveTools must attach stock names or teach/plan have no filesystem tools
- [x] inspect apply timing: session_start, session_tree, tab cycle, before_agent_start
- [x] inject mode layer via systemPromptOptions.sections; do not replace whole systemPrompt

## path + explore

- [x] cwd + path + bash: @gotgenes/pi-permission-system (external_directory ask)
- [x] doom loops: pi-anti-doom-loop
- [x] defaultTools includes grep, find, ls
- [x] workspace section: stay in cwd, local-first, stop on hit

## exa

- [x] slim web-docs: Exa search + contents, drop local HTML stack
- [x] rename tools to web_search / web_fetch
- [x] category + recency + richer tool chrome (│ / ▕)
- [ ] multi-key rotation if rate limits bite

## footer / chrome

- [x] fit footer info around mode indicator
- [x] left/right padding to match bordered input box

## keybinds

- [ ] mode cycle must leave tab free for / menu
- [ ] must not fight shift+tab thinking level
- [ ] pick free chord; update modes.ts + keybindings.json
- [ ] tui.input.tab already cleared — verify full conflict matrix
- [ ] add keybind to refresh scroll back to the bottom

## sounds

- [ ] completion sound on agent turn done
- [ ] reuse nvim ekhos palette (success/ready/chime etc)
- [ ] path: nvim/ekhos + lua/config/ekhos.lua
- [ ] decide: play wav from pi ext vs thin bridge to existing player

## sessions (nushell)

- [ ] script under pi.nu / ai: list sessions from ~/.pi/agent/sessions
- [ ] sort by recent; show id, cwd, name, first message, path
- [ ] delete specific session (trash/rm jsonl)
- [ ] enter/resume selected session (pi --session / -r path)
