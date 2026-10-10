---
tool: claude-app
name: Claude app sessions (claude.ai, desktop, mobile; cloud workspace, optionally linked to a computer)
npm: none
version-url: https://support.claude.com
version: n/a
checked: 2026-10-10
verified: yes 2026-10-10 (model + effort, read back from the session record by the Supervisor seat and the Maintainer seat)
agents-dir: none
docs:
  - https://support.claude.com
---
## 1 What it is · is it alive

Claude sessions opened from the Claude app, in which an agent works in a cloud workspace and can be linked to the person's computer through the desktop app. The session's working directory is in the cloud, **not in the project repo**, so the project's `.claude/agents/` files are **not loaded** — this is why this file exists separately from `claude-code.md`.
Observed 2026-10-10 in such a session: the list of available subagent types contained only built-in ones (general-purpose, Explore, Plan and a few others), no `tier-*`.

## 2 Models

Subagents are dispatched with the session's Agent tool. Its `model` parameter accepts `fable`, `opus`, `sonnet` and `haiku` (from the tool's own parameter list as the session sees it, 2026-10-10). Omitted = the model the agent type or the parent session would use.
The record shows what ran: `haiku` → `claude-haiku-5-5` (see section 7).

## 3 Effort / level

The Agent tool has an `effort` parameter: `low` `medium` `high` `xhigh` `max`. Omitted = the environment's default (observed: `high`).
The tool's own description says to set it only when the person or the project's rules explicitly ask for a level; section 5 of this file **is** that rule, so always pass the level from section 5.
(changed 2026-10-10: was "No per-subagent effort parameter" — the parameter was missed when this file was first written.)

## 4 Subagent files

None. Agent types are built in; there is no project-level place for tier files in this environment.

## 5 Tier mapping

| Tier | Model | Effort | Notes |
|---|---|---|---|
| top | `fable` | `xhigh` | |
| strong | `opus` | `high` | |
| normal | `opus` | `medium` | Cheaper alternative: `sonnet` + `medium` |
| light | `sonnet` | `medium` | Cheaper alternative: `haiku` + `low` |

Same as `claude-code.md` section 5 (Requester, 2026-10-10 19:1x, after effort turned out to be settable). (changed 2026-10-10: was top `fable` · strong `opus` · normal `sonnet` · light `haiku`, no effort.) Not yet compared by running the same task at each tier.

## 6 Files FRAME generates

None. **How to dispatch**: call the Agent tool with `model` **and** `effort` set to the values in section 5 for the label's tier, and start the prompt with `tier: <key>` so the record shows which tier was meant. Labels in tasks and records stay keys (`strong`, `normal`, …) as usual.

## 7 Cannot do · unsure · not verified

- **How to check what actually ran**: the session record `~/.claude/projects/<dir>/<session id>/subagents/agent-<id>.jsonl` has `message.model` (the model the API answered with) and `perTurnEffort` on every assistant turn; `agent-<id>.meta.json` has the `model` / `effort` requested at dispatch.
- Verified 2026-10-10: `model: haiku` without effort → `claude-haiku-5-5` + `high`; `model: haiku` + `effort: low` → `claude-haiku-5-5` + `low` (Supervisor seat). The other three tiers were not dispatched.
- An older build of the session's tools may lack the `effort` parameter; look at the Agent tool's parameter list when a session starts. If it is missing, dispatch with `model` only and say so in the task.
- Whether the platform substitutes a model that is unavailable to the account is not documented here. **If a dispatch with a given model fails, stop that part and ask the Requester with a pop-up multiple choice** (go one tier down / wait / go one tier up), the same road as an upgrade request; record his answer in the task. Never step down on your own (`ai/rules/model-effort.md` section 2, item 5).
