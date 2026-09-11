# pi agent todo

## path + explore

- [ ] shared path resolver for all explore tools
- [ ] cwd free; outside cwd needs permission gate
- [ ] session allowlist of roots (not per-file spam)
- [ ] cover: code-view, code-search, code-files, code-overview, read-image, quickfix
- [ ] after that: drop stock read/grep/find/ls from build active set
- [ ] note: bash still bypasses path policy

## permissions ui

- [ ] find proper pi questions / prompt extension for the gate

## exa

- [ ] calibrate exa-search by search kind (docs vs broad vs domain-locked)
- [ ] tune defaults: type, numResults, includeDomains habits

## quickfix

- [ ] stop clipboard/command paste as the main path
- [ ] reach neovim more directly (rpc / server / socket / open API — decide)

## footer / chrome

- [ ] fit footer info around mode indicator
- [ ] left/right padding to match bordered input box

## keybinds

- [ ] mode cycle must leave tab free for / menu
- [ ] must not fight shift+tab thinking level
- [ ] pick free chord; update modes.ts + keybindings.json
- [ ] tui.input.tab already cleared — verify full conflict matrix

## sounds

- [ ] completion sound on agent turn done
- [ ] reuse nvim ekhos palette (success/ready/chime etc)
- [ ] path: nvim/ekhos + lua/config/ekhos.lua
- [ ] decide: play wav from pi ext vs thin bridge to existing player

## mode tool gate bug

- [ ] repro: UI status shows build, model only gets discovery tools
- [ ] write/edit/bash/read/grep/find/ls missing from model tool list in build
- [ ] inspect setActiveTools vs core stock tool names/registration
- [ ] check apply timing: session_start, session_tree, tab cycle, before_agent_start
- [ ] fix: build must actually expose mutation tools or status is a lie

## sessions (nushell)

- [ ] script under pi.nu / ai: list sessions from ~/.pi/agent/sessions
- [ ] sort by recent; show id, cwd, name, first message, path
- [ ] delete specific session (trash/rm jsonl)
- [ ] enter/resume selected session (pi --session / -r path)
