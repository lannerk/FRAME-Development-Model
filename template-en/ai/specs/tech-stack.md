---
status: to be written by the Reviewer seat (skeleton by the Maintainer seat; the Maintainer does not fill in the content)
version: v0
last updated: 2026-09-15
decisions: —
referenced by: <registered both ways when a task is opened>
prototype: —
owner: **Reviewer seat** (`ai/roles/reviewer.md` §2b)
---

# Technology choices

> **What was chosen, which version, why, and what was rejected.** Every choice **gets its own AD**.
> **The "what was rejected" column may not be left empty** — without it the same option gets raised again every three months.

## 1. In use
| Layer | What was chosen | Version | Why this one | What was rejected | AD |
|---|---|---|---|---|---|
| Language | | | | | |
| Framework | | | | | |
| Storage | | | | | |
| Build | | | | | |
| Deployment | | | | | |

## 2. Which convention the source directory follows

`src/<project>/` is organized internally **by the official convention of that language/framework**; write down which one it is and where the official docs are.
**Don't invent one of your own** — breaking the convention makes the whole toolchain that comes with it (build, test discovery, packaging, IDE indexing) stop working.

## 3. Version discipline
When to upgrade, what to verify before upgrading, which file it is pinned in (`go.mod` / `package-lock.json` / `pyproject.toml`…).

## Change log
| Date | What changed | Why | AD |
|---|---|---|---|
