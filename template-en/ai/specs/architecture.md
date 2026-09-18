---
status: to be written by the Reviewer seat (skeleton by the Maintainer seat; the Maintainer does not fill in the content)
version: v0
last updated: 2026-09-15
decisions: —
referenced by: <registered both ways when a task is opened>
prototype: —
owner: **Reviewer seat** (`ai/roles/reviewer.md` §2b)
---

# System architecture

> **This file is the single source of truth for the architecture.** `docs/architecture.md` keeps only a one-page pointer to it, **don't write a second version there**.
> Changing the architecture **always gets its own AD** — it is the ground other people make decisions on, and when the ground moves with nobody told, everything standing on it comes down.

## 1. The overall shape
One diagram or one paragraph making it clear: which blocks there are, what each is responsible for, who calls whom.

## 2. What each block is
| Component | What it does | Where it runs | What it is not responsible for |
|---|---|---|---|
| | | | |

## 3. Boundaries and entrances
What the single external entrance is, which layer authenticates, which surfaces are not exposed. **Say whether it is fail-open or fail-closed.**

## 4. Preconditions that cannot be touched
The few that cause trouble the moment they are violated (with AD numbers).

## 5. Explicitly not doing
The architecture options ruled out + why. **This section saves more work than the ones above it** — it blocks the recurring "shouldn't we switch to X" discussion.

## Change log
| Date | What changed | Why | AD |
|---|---|---|---|
