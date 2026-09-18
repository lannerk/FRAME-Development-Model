# Current state

> **Every stage's wrap-up must update this file.** It answers one question: **how far it has got, what is on hand, what not to step on again.**
> History does not live here — it lives in `archive/`. This file records **only what still holds now**, capped at 200 lines.
> Last updated: \<YYYY-MM-DD>
>
> 🔔 **Rules last changed: \<YYYY-MM-DD> — \<one line on what changed>**
> If this line is newer than what you remember when you open, **re-read your own `ai/roles/*.md` and `ai/rules/` before you start**.
> **The date above is the effective date**: a rule change is **not retroactive** for tasks pushed to `in review` before it (`ai/rules/workflow.md` §3c).
> (This line is updated by the **Maintainer seat** in the round it finishes changing the rules.)

## 1. What the system looks like

> A new session should finish this section knowing "what this project is, which blocks it is made of, which preconditions cannot be touched".
> Write **facts that hold now**, not history. Give each line a verifiable anchor where you can (file path / version number / decision number).

- **`<the core architecture in one line>`**
- **`<what the backend / frontend / main dependencies are, versions spelled out>`**
- **`<the external entrance, ports, authentication boundary>`**
- **`<old designs already overturned, which nobody may build from again>`** (e.g. a multi-option architecture has converged on one; the related docs stay on record but may not be followed)

## 2. Where it runs and how to get in

| What | Where |
|---|---|
| Repo (the single authoritative source) | `<path>` |
| Version control | `<remote address, branch, who commits>` |
| Machine list | `ops/machines.json` (**the only place an IP may be written**) |
| Deployment | `<one line making the chain clear>` |

**Every stage's changes must be written back to the repo in the same round** — the runtime environment is volatile, the repo is the source.

## 3. What is on hand now

**Tasks in flight**: see `../tasks/index.md`.
**Awaiting the Requester**: see the R table in `../tasks/index.md`.
**Inbox**: `../../product/requirements/inbox.md`, **`pending` must be cleared to zero before a round ends**.

## 4. Numbers measured recently (only useful with a date)

> Only **measured** numbers go here, with the day they were measured. A number with no date is one nobody dares trust next stage.

| Item | Number | Date measured |
|---|---|---|
| | | |

## 5. Don't step on these again (the recent burns; the old pits are in `../rules/conventions.md`)

> One line each, **with an anchor that reproduces it**. This section saves more time than any document — it is tuition somebody else already paid.

1.
2.

## 6. The Requester's tastes (saves a round of rework)

> What he has stressed over and over goes here, so a new session doesn't have to find out by trial and error.

-

## 7. This stage's commit message (the Requester copies it straight out when committing)

```
<one line: what this stage touched + which decisions it maps to>
```
