---
tool: opencode
name: OpenCode
npm: "opencode-ai"
version: 1.18.35
checked: 2026-10-10
verified: no
agents-dir: .opencode/agents
docs:
  - https://opencode.ai/docs/agents/
  - https://opencode.ai/docs/models/
  - https://opencode.ai/docs/config/
  - https://opencode.ai/docs/rules/
---
## 1 What it is · is it alive

Open-source terminal coding agent (TUI) by SST, not tied to one vendor: any provider through the AI SDK and Models.dev. Actively released: npm `opencode-ai` 1.18.35 (`npm view`, checked 2026-10-10).
Project instructions: `AGENTS.md` (falls back to `CLAUDE.md` when there is no `AGENTS.md`); project config `opencode.json` / `opencode.jsonc` and the `.opencode/` folder.

## 2 Models

Format `provider/model-id`, e.g. `anthropic/claude-sonnet-4-5-20250929`, `openai/gpt-5`, `opencode/…` (OpenCode Zen gateway). Source: models page, "The format here is `provider/model`".
Anthropic IDs used in section 5 (`claude-fable-5-1`, `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`) exist in the AI SDK Anthropic provider (`@ai-sdk/anthropic` 4.0.78, checked 2026-10-10); the list OpenCode actually shows comes from Models.dev — check it with `/models`.
`small_model` is a fixed slot for light jobs such as titles; there is no automatic model choice per task.

## 3 Effort / level

Called **variants**, per model. Built-in: Anthropic `high` (default) and `max`; OpenAI roughly `none` … `xhigh` by model; Google `low` and `high`. Switched with the `variant_cycle` key; custom variants go under the model's `variants`.
In an agent, "any other options you specify … will be passed through directly to the provider as model options" (agents page). The Anthropic provider's option is `effort` (`low` `medium` `high` `xhigh` `max`); OpenAI's is `reasoningEffort`. No `variant` field for agents is documented.

## 4 Subagent files

Project level: `.opencode/agents/<name>.md` (global `~/.config/opencode/agents/`); the **file name is the agent name**. Markdown with YAML frontmatter; required `description`; optional `mode` (`primary` / `subagent` / `all`, default `all`), `model`, `temperature`, `top_p`, `steps`, `permission`, `hidden`, `disable`, `color`. Without `model`, a subagent uses the model of the primary agent that called it.
The same can be written under the `agent` key of `opencode.json`.
The primary agent calls a subagent through its Task tool by `description`, or the person types `@tier-strong …`. Passing a model at call time: not documented.

## 5 Tier mapping

| Tier | Model | Effort | Notes |
|---|---|---|---|
| top | `anthropic/claude-fable-5-1` | `max` | |
| strong | `anthropic/claude-opus-5-5` | `high` | |
| normal | `anthropic/claude-sonnet-5-5` | `medium` | OpenAI alternative: `openai/gpt-6.1-sol` with `reasoningEffort: medium` instead of `effort` |
| light | `anthropic/claude-haiku-5-5` | `low` | Or any cheap model the project already has a key for |

Written for the Anthropic provider; another provider changes only `model` and the name of the effort key. Suggested values from the Supervisor's plan of 2026-10-10, approved by the Requester.

## 6 Files FRAME generates

`.opencode/agents/tier-top.md`

```markdown
---
description: FRAME tier top. Use when the main session says "use tier-top" or the task part is labelled top.
mode: subagent
model: anthropic/claude-fable-5-1
effort: max
---
You are a FRAME execution subagent (tier: top). The main session gives you the work, the material and the reply format in one go.
Do what you are given and do not widen the scope; write "unsure" rather than guessing; reply in the requested format and list the files you changed.
```

`.opencode/agents/tier-strong.md` — same body, `model: anthropic/claude-opus-5-5`, `effort: high`, `(tier: strong)`.
`.opencode/agents/tier-normal.md` — `model: anthropic/claude-sonnet-5-5`, `effort: medium`, `(tier: normal)`.
`.opencode/agents/tier-light.md` — `model: anthropic/claude-haiku-5-5`, `effort: low`, `(tier: light)`.
In each, `description` says the same as above with its own key. There is no `name` field: the file name is the name.

## 7 Cannot do · unsure · not verified

- **Unsure**: that `effort:` in a Markdown agent reaches the provider — the pass-through is documented, but its only example is JSON. If it is ignored, the subagent runs at the model's default variant (Anthropic: `high`).
- **Unsure**: the exact IDs Models.dev lists for the 5.x Anthropic models; if `/models` shows other spellings, change section 5 and regenerate.
- The main session cannot pick a model when it dispatches; tiers only work through the four files.
- **Not verified in a project yet** (`verified: no`).
