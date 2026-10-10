# `ai/ide/` — each tool's implementation of the four-tier interface

> The rules themselves are in `ai/rules/model-effort.md` (the four tiers, labels, who labels, the switch). This directory answers one question only: **in a given AI coding tool, what does each tier become.**
> 🔴 **Implementation files are written once, in English**, and shared by projects in every language (they hold paths, fields, model IDs and links to official docs). This README exists in two languages.

## 1. One file per tool; the file name is the tool name

The file name is the value written in `ide=` in `ai/frame-repo.conf` (lower case, hyphens) and the word used in the command `ide <tool>`.
Tools that were researched but are not in use go into `_spare/`, same format; move one out when someone needs it.

## 2. What each file looks like

A machine-readable header, then seven sections:

```markdown
---
tool: claude-code                 # = the file name
name: Claude Code
npm: "@anthropic-ai/claude-code"  # none if there is no npm package; give version-url instead
version: 2.1.296                  # the version at the last check
checked: 2026-10-10               # the date of the last check
verified: no                      # yes (with the date) only after really dispatching light and strong once in a project and seeing the model and level that ran
agents-dir: .claude/agents        # where the four tier files go; none if the tool has no subagent files
docs:                             # pages to re-read when updating, most important first
  - https://…
---
## 1 What it is · is it alive
## 2 Models (what can be chosen; alias or full ID)
## 3 Effort / level (name, how many steps, where it is set)
## 4 Subagent files (path, format, field names)
## 5 Tier mapping   ← this is the table every seat uses
## 6 Files FRAME generates (the four, verbatim)
## 7 Cannot do · unsure · not verified
```

**Rules for the section 5 mapping table**: one row per tier, four columns: tier, model (**aliases first** — an alias follows the next generation by itself; a full ID only when there is no alias), level, notes. A level that cannot be written into the subagent file gets a note saying where to set it instead; a tool that cannot offer four tiers says how they merge ("top = strong"). The table holds **suggested values**: if the Requester changes them, change this file; the interface and the tasks do not move.

**The common body of the four tier files** (only the header format differs per tool):

```
You are a FRAME execution subagent (tier: <key>). The main session gives you the work, the material and the reply format in one go.
Do what you are given and do not widen the scope; write "unsure" rather than guessing; reply in the requested format and list the files you changed.
```

`description` is always: `FRAME tier <key>. Use when the main session says "use tier-<key>" or the task part is labelled <key>.`
(In some tools the main session cannot name a subagent on the spot and routing goes by `description` alone; this sentence is what it routes on.)

## 3. How to update

1. Run `bash ops/scripts/ide-refresh.sh <tool>` (or `--all`): it reads the header, compares the npm version with `version:` where there is a package and prints "changed / unchanged"; a `checked:` older than 90 days is flagged "stale". **Version unchanged and under 90 days → no update needed.**
2. Changed → dispatch one `light` subagent to re-read the `docs:` pages in order, **checking only three things**: the subagent file path and field names (section 4), model aliases / IDs and level values (sections 2 and 3), and whether the project-level config file was renamed.
3. Edit sections 4, 5 and 6 point by point; prefix each change with `(changed 2026-xx-xx: was …)` and keep the old value on one line for rollback.
4. Update `version:` and `checked:` in the header; if the four files in section 6 changed, regenerate them in the project through the `ide <tool>` routine. **If sections 5 or 6 changed, set `verified:` back to `no` until tested again.**
5. Run `bash ops/verify/check-ide.sh`; one maintenance-log entry; these files are FRAME itself, so send them back to the source repo and stamp a version.

**Why not scrape the pages automatically**: vendors' doc sites often forbid scraping and move their paths; the only thing a script can do reliably is the version number. Whether the docs changed is step 2, read by a person.

## 4. What is here now

| Tool | File | Tested |
|---|---|---|
| Claude Code | `claude-code.md` | no (`verified: no`) |

The rest of the first batch (Codex, Cursor, Copilot, Kiro, Cline, TRAE, Qoder, OpenCode, CodeBuddy, Gemini CLI, Antigravity) and the twelve spares are being added; until then `ide <tool>` accepts only what this table lists.
