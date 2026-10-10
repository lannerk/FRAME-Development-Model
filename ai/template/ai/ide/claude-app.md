---
tool: claude-app
name: Claude app sessions (claude.ai, desktop, mobile; cloud workspace, optionally linked to a computer)
npm: none
version-url: https://support.claude.com
version: n/a
checked: 2026-10-10
verified: yes 2026-10-10 (the model parameter only; effort cannot be set)
agents-dir: none
docs:
  - https://support.claude.com
---
## 1 What it is · is it alive

Claude sessions opened from the Claude app, in which an agent works in a cloud workspace and can be linked to the person's computer through the desktop app. The session's working directory is in the cloud, **not in the project repo**, so the project's `.claude/agents/` files are **not loaded** — this is why this file exists separately from `claude-code.md`.
Observed 2026-10-10 in such a session: the list of available subagent types contained only built-in ones (general-purpose, Explore, Plan and a few others), no `tier-*`.

## 2 Models

Subagents are dispatched with the session's Agent tool. Its `model` parameter accepts `fable`, `opus`, `sonnet` and `haiku` (from the tool's own parameter list as the session sees it, 2026-10-10). Omitted = the model the agent type or the parent session would use.

## 3 Effort / level

**No per-subagent effort parameter.** A subagent runs at whatever effort the environment gives it.

## 4 Subagent files

None. Agent types are built in; there is no project-level place for tier files in this environment.

## 5 Tier mapping

| Tier | Model | Effort | Notes |
|---|---|---|---|
| top | `fable` | — | |
| strong | `opus` | — | |
| normal | `sonnet` | — | Differs from `claude-code.md` (where normal = opus + medium): with no effort available, the tiers are separated by model alone |
| light | `haiku` | — | |

Chosen by the Maintainer on 2026-10-10 from the Claude Code mapping and its cheaper alternatives, approved by the Requester; not yet compared by running the same task at each tier.

## 6 Files FRAME generates

None. **How to dispatch**: call the Agent tool with `model` set to the value in section 5 for the label's tier, and start the prompt with `tier: <key>` so the record shows which tier was meant. Labels in tasks and records stay keys (`strong`, `normal`, …) as usual.

## 7 Cannot do · unsure · not verified

- Effort cannot be set per subagent.
- Verified 2026-10-10 only that a dispatch with `model: haiku` was accepted and ran (a one-word reply); **not** which model actually answered — the session does not show it.
- Whether the platform substitutes a model that is unavailable to the account is not documented here; if a dispatch with a given model fails, fall back one tier down for that part only and say so in the task.
