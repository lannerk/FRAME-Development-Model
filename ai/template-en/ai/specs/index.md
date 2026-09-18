# Technical spec index

> **A spec is what you must read before starting once it is settled, not reference material.** If a task says `spec:`, that is the one to read before you start.
> A spec **is updated as the implementation moves**: when implementation and spec disagree, **change the spec**; don't leave it frozen on the day it was proposed.
> File names carry no prefix like "technical-spec-" (the directory already says what it is).

## Promotion and updating (the same rules as for design files)

**While it is a draft** write it in `claude-outputs/reviewer/`, change it however you like.
**Once the Reviewer and the Requester have confirmed it**, move it here, and:

1. Add the file header (status / version / last updated / decisions / referenced by / prototype);
2. **Register a row in the table below** (including "last updated");
3. Fill `spec:` in the task file to point at it.

**Settle one thing before moving it: is this a new spec, or an update to an existing one?**
**The Reviewer and the Requester confirm that; you don't decide it yourself.** The test is "**does it govern the same block of functionality**",
**not "how big this change is"** — adding an option to a feature or swapping its implementation still governs that same feature, so that is **an update to the existing one**.

| Case | What to do |
|---|---|
| **A new block of functionality** | Open a new `<name>.md`, add the file header, add a row to the table |
| **A new version of an existing spec** | **Change that one file**: bump the version + add a change-log line + update "last updated" in the table + leave a line in each open task that references it |

🔴 **No `xxx-v2.md` or `xxx-new.md` files.** One block of functionality scattered across two files means development doesn't know which to trust —
and that mistake has no symptom at all until somebody has finished building from the old one. Only dropped ones move into `archive/` and get struck through below.

**Four rules**: ① a task's "spec" must point at a spec or an AD; ② whoever changes the implementation changes the spec, finished in the same stage;
③ "referenced by" goes both ways; ④ a spec does not record "how far the implementation got" — that is the job of the task and the decision's implementation column.

## In use

| Spec | What it governs | Status | Decisions | Last updated |
|---|---|---|---|---|
| `architecture.md` | **System architecture** (the single source of truth) | to be filled in | — | `<date>` |
| `database.md` | **Database design** | to be filled in | — | `<date>` |
| `tech-stack.md` | **Technology choices** | to be filled in | — | `<date>` |
| `testing.md` | **How this project is tested** (the means · environment · action · evidence for the eight kinds) | to be filled in | — | `<date>` |
| | | | | |

> These four templates ship with a skeleton and **all belong to the Reviewer seat**: `testing.md` gets filled in before the first "review and test";
> `architecture.md` `database.md` `tech-stack.md` before the first task is opened — **development builds from them**.

## Proposed (not settled, don't build from these)

| Spec | What it governs | Status | Decisions | Last updated |
|---|---|---|---|---|
| | | | | |

## 🗑 Dropped (in `archive/`, kept on record, **do not build from them**)

| Spec | What it governs | Status | Note |
|---|---|---|---|
| | | | |
