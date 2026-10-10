---
tool: claude-code
name: Claude Code
npm: "@anthropic-ai/claude-code"
version: 2.1.296
checked: 2026-10-10
verified: no
agents-dir: .claude/agents
docs:
  - https://code.claude.com/docs/en/sub-agents
  - https://code.claude.com/docs/en/model-config
  - https://code.claude.com/docs/en/settings
---
## 1 What it is · is it alive

Anthropic's agentic coding tool (terminal, IDE, desktop and web). Actively released: npm `@anthropic-ai/claude-code` 2.1.296, published 2026-10-09 (`npm view`, checked 2026-10-10).

## 2 Models

Aliases accepted in a subagent's `model:` field: `sonnet`, `opus`, `haiku`, `fable`, a full model ID (e.g. `claude-opus-5-5`), or `inherit` (same as the main conversation). Source: sub-agents page, "Choose a model".
On the Anthropic API (model-config page, 2026-10-10): `fable` = Fable 5.1, `opus` = Opus 5.5, `sonnet` = Sonnet 5.5, `haiku` = Haiku 5.5. Aliases follow new generations by themselves, so section 5 rarely needs editing.
On Amazon Bedrock, Google Cloud's Agent Platform and Microsoft Foundry the aliases map to older models, and `fable` does not resolve unless `ANTHROPIC_DEFAULT_FABLE_MODEL` is set.

## 3 Effort / level

Subagent frontmatter field `effort:` with `low` `medium` `high` `xhigh` `max`; the levels actually available depend on the model (Fable 5.1, Opus 5.5, Sonnet 5.5, Haiku 5.5: all five). It overrides the session's effort level.
Defaults: `high` on models that support effort, except Opus 5.5, Sonnet 5.5 and Haiku 5.5, which default to `medium`.
`max` is accepted in the subagent field but **not** in the settings key `effortLevel`.

## 4 Subagent files

Project level: `.claude/agents/<name>.md` (scanned recursively; the definition closest to the working directory wins on a name clash). Markdown with YAML frontmatter; required `name` (≤256 chars, no `:`) and `description`; optional `model`, `effort`, `tools`, `permissionMode`, `maxTurns` and more.
The main session can request one by name in plain language ("use the tier-strong subagent for …") or with `@agent-tier-strong`.

## 5 Tier mapping

| Tier | Model | Effort | Notes |
|---|---|---|---|
| top | `fable` | `xhigh` | Where Fable is not available (Bedrock / Agent Platform / Foundry without `ANTHROPIC_DEFAULT_FABLE_MODEL`): `opus` + `xhigh` |
| strong | `opus` | `high` | |
| normal | `opus` | `medium` | Cheaper alternative: `sonnet` + `medium` |
| light | `sonnet` | `medium` | Cheaper alternative: `haiku` + `low` |

Suggested values from the Supervisor's plan of 2026-10-10, approved by the Requester; not yet compared by running the same task at each tier.

## 6 Files FRAME generates

`.claude/agents/tier-top.md`

```markdown
---
name: tier-top
description: FRAME tier top. Use when the main session says "use tier-top" or the task part is labelled top.
model: fable
effort: xhigh
---
You are a FRAME execution subagent (tier: top). The main session gives you the work, the material and the reply format in one go.
Do what you are given and do not widen the scope; write "unsure" rather than guessing; reply in the requested format and list the files you changed.
```

`.claude/agents/tier-strong.md` — same body with `name: tier-strong`, `model: opus`, `effort: high`, `(tier: strong)`.
`.claude/agents/tier-normal.md` — `name: tier-normal`, `model: opus`, `effort: medium`, `(tier: normal)`.
`.claude/agents/tier-light.md` — `name: tier-light`, `model: sonnet`, `effort: medium`, `(tier: light)`.
In each, `description` says the same as above with its own key.

## 7 Cannot do · unsure · not verified

- Two environment variables override everything here: `CLAUDE_CODE_SUBAGENT_MODEL` together with `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` forces one model onto every subagent and ignores `model:`; `CLAUDE_CODE_EFFORT_LEVEL` beats the `effort:` field. **Do not set them** in a project that uses these rules.
- An administrator's `maxEffortLevel` (or per-model caps) caps effort; a higher request runs at the cap.
- The main session's own model and effort are chosen by the person who opens it; FRAME does not set them.
- **Not verified in a project yet** (`verified: no`): that the four files above are picked up, and that the model and effort that actually run match section 5.
