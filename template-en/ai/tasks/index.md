# Task index

> **One task, one file**, named `T-<four-digit number>-<a short title of a few words>.md`. Only a one-line summary goes here, **open the task file for the detail**.
> For the state machine and the template see `../rules/workflow.md`.
> **Next available task number: T-0001** (whoever uses one adds one, same rule as taking a decision number)

## In flight (the Developer reads this table first when starting a stage)

| # | Title | Status | Priority | Assigned to | Related |
|---|---|---|---|---|---|
| | | | | | |

**Priority**: P0 right now → P1 this stage → P2 next stage → P3 when free → P4 don't forget.
**`blocked`** must say in "Related" what it is waiting for and who unlocks it once that arrives. If it never arrives, move it to `dropped`; don't leave it hanging for show.

## Awaiting the Requester (the ones none of the three parties can move; don't clutter the table above with them)

| # | What the Requester has to do | Because | How long it takes |
|---|---|---|---|
| | | | |

> Every line must answer "how many minutes of his time, and what it unlocks". Save them up and ask in one batch (hard law 5).

## Archived

`archive/` holds them flat under their original `T-####` names, moved in **once they have been `passed` for 3 full stages**. Archiving only moves them off the reading path; nothing is deleted.
To find one: `grep -rl "T-0042" archive/`.

## Three things you must not do

1. **No second to-do list.** The same thing recorded in two places will never have matching states.
2. **No state written only in the conversation.** The session changes between stages, and nothing said in the conversation is visible in the next one.
3. **No task file growing into an incident report** (cap 150 lines). Write the investigation into the measured subsection of "Developer report"; a long one gets its own file under `claude-outputs/developer/` with a signpost here.
