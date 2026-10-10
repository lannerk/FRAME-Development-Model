---
tool: qoder
name: Qoder / Qoder CN (formerly Tongyi Lingma)
npm: "@qoder-ai/qodercli"
version: 1.1.67
checked: 2026-10-10
verified: no
agents-dir: .qoder/agents
docs:
  - https://docs.qoder.com/zh/cli/subagent.md
  - https://docs.qoder.com/cli/model.md
  - https://docs.qoder.com/cli/settings.md
  - https://docs.qoder.com/release-notes/qoder-cli.md
---
## 1 What it is · is it alive

Alibaba's agentic coding platform: desktop IDE, CLI (`qodercli`; China build `@qodercn-ai/qoderclicn`), JetBrains plugin, SDK. Tongyi Lingma was renamed **Qoder CN** in 2026 and uses the same files (its user folder is `~/.qoder-cn`, which does not affect project files). Actively released: npm `@qoder-ai/qodercli` 1.1.67 (`npm view`, checked 2026-10-10).
Project instructions: `AGENTS.md`, `AGENTS.local.md`, `.qoder/rules/**/*.md`; settings `.qoder/settings.json`.

## 2 Models

The default choices are **tiers, not model names**: `auto` (smart routing), `ultimate`, `performance`, `efficient` (model page). Which model sits behind each tier is not published. Named models can also be picked (Qwen3.8-Max, Kimi-K3, GLM-5.3, DeepSeek-V4-Pro and others), and custom models with your own key.
The subagent page lists `inherit` (default), `auto`, `lite`, `efficient`, `performance` as common `model:` values and accepts any model name or alias; `ultimate` is listed in the SDK agents page.

## 3 Effort / level

**Thinking effort**: `low` `medium` `high` `xhigh` `max` (subagent field `effort:` also takes a positive integer budget). Per the model page, only Ultimate and Performance support thinking effort; the levels available depend on the model. Session: `/effort high`, `--reasoning-effort high`, settings `model.reasoningEffort`.

## 4 Subagent files

Project level: `.qoder/agents/<name>.md` (subject to folder trust; user level `~/.qoder/agents/`). **The name comes from `name:`, not the file name.**
Markdown with YAML frontmatter; required `name` and `description`; optional `model`, `effort`, `tools`, `disallowedTools`, `permissionMode`, `maxTurns`, `timeoutMins`, `temperature`, `isolation`, `memory`, `background` and more. Unknown fields are ignored.
The main session can name one ("use the tier-strong subagent …" or `@tier-strong`).

## 5 Tier mapping

| Tier | Model | Effort | Notes |
|---|---|---|---|
| top | `ultimate` | `max` | Costs about 2× credits |
| strong | `performance` | `high` | |
| normal | `performance` | `medium` | Or `auto` |
| light | `efficient` | `low` | Efficient may ignore effort; harmless to write |

Suggested values from the Supervisor's plan of 2026-10-10, approved by the Requester.

## 6 Files FRAME generates

`.qoder/agents/tier-top.md`

```markdown
---
name: tier-top
description: FRAME tier top. Use when the main session says "use tier-top" or the task part is labelled top.
model: ultimate
effort: max
---
You are a FRAME execution subagent (tier: top). The main session gives you the work, the material and the reply format in one go.
Do what you are given and do not widen the scope; write "unsure" rather than guessing; reply in the requested format and list the files you changed.
```

`.qoder/agents/tier-strong.md` — same body with `name: tier-strong`, `model: performance`, `effort: high`, `(tier: strong)`.
`.qoder/agents/tier-normal.md` — `name: tier-normal`, `model: performance`, `effort: medium`, `(tier: normal)`.
`.qoder/agents/tier-light.md` — `name: tier-light`, `model: efficient`, `effort: low`, `(tier: light)`.
In each, `description` says the same as above with its own key.

## 7 Cannot do · unsure · not verified

- **Do not use `lite`**: the Lite tier was withdrawn on 2026-09-18 (requests naming it fail), although the subagent page still lists it as a common value.
- **Unsure**: that `ultimate` is accepted in a subagent file (it is in the SDK page, not in the subagent page's common values). If it is rejected, top = `performance` + `max`.
- **Unsure**: whether the Qoder IDE (not the CLI) reads `.qoder/agents/`; the docs only say so for the CLI. IDE custom agents are made in Settings > Agent.
- The environment variable `QODER_CLI_MAX_CONCURRENT_SUBAGENTS` limits parallel subagents; only one level of nesting by default.
- **Not verified in a project yet** (`verified: no`).
