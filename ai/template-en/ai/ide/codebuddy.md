---
tool: codebuddy
name: CodeBuddy Code (Tencent)
npm: "@tencent-ai/codebuddy-code"
version: 2.164.0
checked: 2026-10-10
verified: no
agents-dir: .codebuddy/agents
docs:
  - https://www.codebuddy.cn/docs/cli/sub-agents
  - https://www.codebuddy.cn/docs/cli/settings
  - https://www.codebuddy.cn/docs/cli/models
  - https://www.codebuddy.cn/docs/cli/release-notes/README
---
## 1 What it is · is it alive

Tencent Cloud's coding assistant: CLI **CodeBuddy Code** (command `codebuddy`), IDE (copilot.tencent.com/ide, codebuddy.ai), IDE plugins, SDK. Released almost daily: npm `@tencent-ai/codebuddy-code` 2.164.0 (`npm view`, checked 2026-10-10).
Project instructions: `CODEBUDDY.md` or `.codebuddy/CODEBUDDY.md`, `.codebuddy/rules/*.md`; `AGENTS.md` only when there is no `CODEBUDDY.md`. Settings `.codebuddy/settings.json`.

## 2 Models

No public model catalogue. Model IDs seen in official examples: `gpt-5.1-codex`, `gpt-6-sol`, `gemini-3.0-flash`, `deepseek-v4-pro`, `deepseek-v4-flash`, `glm-4.6`, plus Tencent Hunyuan. Custom OpenAI-compatible models go in `.codebuddy/models.json`.
**Two scenario slots**: `lite` (fast) and `reasoning` (deep). Which model each slot means is set once in settings `variantModels` (`{"lite": "…", "reasoning": "…"}`); empty = product default.

## 3 Effort / level

`minimal` `low` `medium` `high` `xhigh` `max`. Session: settings `reasoningEffort`; subagent: field `effort:` ("omitted = inherit the session's effort"). A custom model only gets the levels in its `reasoning.supportedEfforts`; higher requests drop to `high`.

## 4 Subagent files

Project level: `.codebuddy/agents/<name>.md` (highest priority; then `--agents` JSON, user `~/.codebuddy/agents/`, plugins).
Markdown with YAML frontmatter; required `name` (lowercase and hyphens) and `description`; optional `model` (model ID / name / alias, `lite`, `reasoning`, `inherit` / `default`), `effort`, `tools`, `disallowedTools`, `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `background`, `memory`, `initialPrompt`.
The main session can name one, and **can pass a model at call time** (model ID, `default`, `lite` or `reasoning`; second in priority after the environment variable below).

## 5 Tier mapping

| Tier | Model | Effort | Notes |
|---|---|---|---|
| top | `reasoning` | `max` | Point `variantModels.reasoning` at the strongest model you have (e.g. `deepseek-v4-pro` / `gpt-6-sol`) |
| strong | `reasoning` | `high` | |
| normal | `inherit` | `medium` | Follows the main session's model |
| light | `lite` | `low` | Point `variantModels.lite` at a cheap model (e.g. `deepseek-v4-flash` / `gemini-3.0-flash`) |

The files name slots, not models, so changing models is one edit in `variantModels`. Suggested values from the Supervisor's plan of 2026-10-10, approved by the Requester.

## 6 Files FRAME generates

`.codebuddy/agents/tier-top.md`

```markdown
---
name: tier-top
description: FRAME tier top. Use when the main session says "use tier-top" or the task part is labelled top.
model: reasoning
effort: max
---
You are a FRAME execution subagent (tier: top). The main session gives you the work, the material and the reply format in one go.
Do what you are given and do not widen the scope; write "unsure" rather than guessing; reply in the requested format and list the files you changed.
```

`.codebuddy/agents/tier-strong.md` — same body with `name: tier-strong`, `model: reasoning`, `effort: high`, `(tier: strong)`.
`.codebuddy/agents/tier-normal.md` — `name: tier-normal`, `model: inherit`, `effort: medium`, `(tier: normal)`.
`.codebuddy/agents/tier-light.md` — `name: tier-light`, `model: lite`, `effort: low`, `(tier: light)`.
In each, `description` says the same as above with its own key.
FRAME does **not** write `.codebuddy/settings.json` (the tool's own file): the Requester sets `variantModels` there once, or leaves the product defaults.

## 7 Cannot do · unsure · not verified

- The environment variable `CODEBUDDY_CODE_SUBAGENT_MODEL` forces one model onto every subagent and beats everything here. **Do not set it** in a project that uses these rules. `CODEBUDDY_SMALL_FAST_MODEL` / `CODEBUDDY_BIG_SLOW_MODEL` override the two slots.
- **Unsure**: whether the CodeBuddy IDE's subagents honour `effort:` (the IDE page does not list it).
- **Unsure**: what models the product defaults put behind `lite` and `reasoning` when `variantModels` is empty.
- **Not verified in a project yet** (`verified: no`).
