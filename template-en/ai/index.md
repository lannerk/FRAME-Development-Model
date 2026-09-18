# <project name> · Index (map of the whole project)

> Cap: 80 lines. **At the start read `CLAUDE.md` → your role manual → this one**, then jump by the signposts; do not read any large file end to end.

## Four roles, each reads its own

| Role | Manual | Duty in one line | Where the output lands |
|---|---|---|---|
| Developer | `roles/developer.md` | implement the features reliably | `src/` · the "Developer report" in the task file |
| Reviewer | `roles/reviewer.md` | senior technical expert: reviews code/specs, faces the Requester, schedules the work | the "Review verdict" in the task file · `decisions/` · `specs/` |
| Supervisor | `roles/supervisor.md` | the Requester's all-round technical advisor, communicates separately | `claude-outputs/supervisor/` (committed as is) |
| **Maintainer** | `roles/maintainer.md` | **maintains this development model itself**, does not develop, does not touch requirements | `ai/rules/` · `ai/roles/` · `ai/template/` |

All four must obey: `rules/laws.md` (the hard laws) · `rules/conventions.md` (engineering conventions) · `rules/workflow.md` (how to work together) · `rules/layout.md` (where things go) · **`rules/investigate.md` (how to investigate an "it's broken")**

## Looking for something → go here

| Looking for | Go to |
|---|---|
| what is being worked on / who is stuck | `tasks/index.md` |
| what a decision settled (AD number) | `decisions/index.md` → jump by number-range file (each entry carries a topic tag, greppable) |
| **how to investigate an "it's broken"** (both the Developer seat and the Reviewer seat read it) | `rules/investigate.md` (the first-hour handbook, five steps; read it the moment you get a bug) |
| the technical spec for a feature | `specs/index.md` (with status: proposed / settled / dropped) |
| what the system looks like now, the recent pitfalls | `state/now.md` (≤200 lines) |
| **things he handed over that hold from then on** (where to get the token, machine quirks, his preferences) | `memory.md` (**project memory**, all four seats read it and all four may write it; **what duplicates the rules is not recorded**) |
| **What another seat left me** | `mail/to-<my seat>/` (**seat mail**, one file per sender, unread only; rules in `mail/README.md`) |
| **every sentence the Requester said and where it got to** | `../product/requirements/inbox.md` (**the inbox**, `pending` down to zero before a round ends) |
| what has been changed in this model and why | `rules/maintenance-log.md` (**the maintenance log**, Maintainer only, a separate line from the inbox) |
| the Requester's words in full | `../product/requirements/verbatim/` |
| the cleaned-up, acceptance-ready specs | `../product/requirements/specs/` |
| formal requirements | `../product/requirements/formal/` |
| the product vision | `../product/vision.md` |
| how the system is built / what is what in the directories / the feature list | `../docs/architecture.md` · `../docs/repo-layout.md` · `../docs/features.md` |
| deployment / testing / troubleshooting / the real machine | `../docs/ops/` |
| source | `../src/` |
| the machine list (**the only place an IP may be written**) | `../ops/machines.json` |
| prototypes / UI baseline | `../product/design/` |
| screenshots / measured output / one-off reports | `../claude-outputs/` |
| history (not read by default) | each directory's `archive/` + the root `archive/` |

## Taking a number and registering it (one entrance only, no writing your own)

| Want | Go to |
|---|---|
| a decision number AD | "next available number" at the top of `decisions/index.md`, **whoever uses one adds one** |
| a task number T-#### | "next available task number" at the top of `tasks/index.md`, same rule |

## Current state (the Developer updates these three lines when wrapping up a stage)

- Test machine: see `../ops/machines.json`
- Last delivery: <which stage>
- Last review: <which round>

## Five things you must not do

1. **No second to-do list** — the to-do list is `tasks/index.md`, the handover is `state/now.md`.
2. **No state written only in the conversation** — the session changes between stages, and nothing said in the conversation is visible in the next one.
3. **No loose files at the root of `ai/`** — only `index.md` and `check-links.sh`, those two.
4. **Nothing may be referenced out of `tmp/`.**
5. **No conclusion without evidence in a formal file** (hard law 7).
