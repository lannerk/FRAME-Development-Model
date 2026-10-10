---
tool: trae
name: TRAE
npm: none
version-url: https://docs.trae.cn/ide/changelog
version: 3.4.0
checked: 2026-10-10
verified: no
agents-dir: .trae/agents
docs:
  - https://docs.trae.cn/ide_subagents
  - https://docs.trae.cn/ide/models
  - https://docs.trae.cn/ide_rules
  - https://docs.trae.cn/ide/changelog
---
## 1 What it is · is it alive

ByteDance's AI IDE (VS Code family). China edition trae.cn (user folder `~/.trae-cn`) and international edition trae.ai. Actively released: v3.4.0 on 2026-10-08 (changelog, checked 2026-10-10). No official CLI (`bytedance/trae-agent` on GitHub is a separate research agent, not the IDE).
Project instructions: `.trae/rules/*.md`; root `AGENTS.md` and `CLAUDE.md` once their switches are on in Settings > Rules.

## 2 Models

China edition built-ins (models page, 2026-10-10): ByteDance Seed (Seed-Evolving for members only, Seed-2.1-Pro, Seed-2.1-Turbo, Seed-Code), GLM-5.3 / 5.3-Flash / 5.3-FlashX / 5.2, DeepSeek-V4-Pro / V4-Flash (with "Official" variants) / V4.1-Flash, Kimi-K3 / K2.8-Preview, MiniMax-M3, Qwen3.8-Max / 3.8-Flash / 3.7-Plus, Step-5-Preview.
**The subagent `model:` field takes its own ID list, spelled differently from the UI names** (subagents page): `Doubao-Seed-Evolving` `Doubao-Seed-2.1-Pro` `Doubao-Seed-2.1-Turbo` `Doubao_1_6` `glm-5.3-flash` `glm-5.3` `glm-5.2` `DeepSeek-V4-Flash-Official` `DeepSeek-V4-Flash` `DeepSeek-V4-Pro-Official` `DeepSeek-V4-Pro` `kimi-k3` `kimi-k2.7-code` `minimax-m3` `qwen-3.8-flash` `qwen-3.8-max` `qwen-3.7-plus`. Only built-in models; custom models cannot be used by subagents.
International edition model list: not found (docs.trae.ai blocks fetching).

## 3 Effort / level

**None.** There is no reasoning-effort setting. Max mode widens the context to 1M per turn (a cost switch, not a reasoning level) and is turned on by hand in the model list; custom models have an on/off "thinking" switch. Subagents can set neither.

## 4 Subagent files

Project level: `.trae/agents/<name>.md` (user level `~/.trae-cn/agents/`; project wins on a name clash). Needs Settings > Beta > Subagents > "Enable Subagents directory" (usually on by default now).
Markdown with YAML frontmatter; required `name` (starts with a letter; letters, digits, hyphens; ≤50 chars) and `description`; optional `model`, `tools`, `disallowedTools`, `mcpServers`. Without `model`, the subagent uses the model chosen in the chat box.
The main Agent picks a subagent **only by its `description`**; it cannot be named or given a model at call time.

## 5 Tier mapping

| Tier | Model | Effort | Notes |
|---|---|---|---|
| top | `Doubao-Seed-Evolving` | — | Members only; otherwise `DeepSeek-V4-Pro-Official`. Turn Max mode on by hand in the main session when the context is huge |
| strong | `DeepSeek-V4-Pro` | — | Or `Doubao-Seed-2.1-Pro` / `kimi-k3` |
| normal | `Doubao-Seed-2.1-Turbo` | — | Or `glm-5.3` |
| light | `qwen-3.8-flash` | — | Or `glm-5.3-flash` |

Model is the only dimension. China edition; suggested values from the Supervisor's plan of 2026-10-10, approved by the Requester.

## 6 Files FRAME generates

`.trae/agents/tier-top.md`

```markdown
---
name: tier-top
description: FRAME tier top. Use when the main session says "use tier-top" or the task part is labelled top.
model: Doubao-Seed-Evolving
---
You are a FRAME execution subagent (tier: top). The main session gives you the work, the material and the reply format in one go.
Do what you are given and do not widen the scope; write "unsure" rather than guessing; reply in the requested format and list the files you changed.
```

`.trae/agents/tier-strong.md` — same body with `name: tier-strong`, `model: DeepSeek-V4-Pro`, `(tier: strong)`.
`.trae/agents/tier-normal.md` — `name: tier-normal`, `model: Doubao-Seed-2.1-Turbo`, `(tier: normal)`.
`.trae/agents/tier-light.md` — `name: tier-light`, `model: qwen-3.8-flash`, `(tier: light)`.
In each, `description` says the same as above with its own key — **routing depends on it entirely**, so keep the sentence.

## 7 Cannot do · unsure · not verified

- No effort level anywhere; tiers differ only by model.
- Routing is automatic: the main Agent may not pick the tier file even when told "use tier-strong". If it keeps missing, say the tier key in the request and check which subagent ran.
- International edition: model IDs not found; do not use these files there unchecked.
- **Not verified in a project yet** (`verified: no`).
