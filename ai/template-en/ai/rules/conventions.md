# Engineering conventions

> **Scan the headings before you start, and steer around the holes already stepped in.** The parentheses after each entry say which incident it came from.
> Limit 150 lines. Every time you add one, think about whether you can merge one away.
>
> **§1 §2 §5 §6 §7 are generic and usable as-is; §3 §4 must be filled in for your project.**

---

## 1. Versions and rollback

1. **Get old versions from version control; don't stack copies in the repo.**
   ```
   git log --oneline -- <file>      # which times it changed
   git show <sha>:<path>            # print that version out
   ```
2. **`tmp/` holds only the narrow window of "changed this stage but not committed yet"**, emptied when the next stage starts.
   Don't stack old files stage by stage — stack them long enough and nobody dares delete, and you end up clearing gigabytes of garbage by hand.
3. **Write a one-line commit message at every stage's wrap-up**, at the end of `ai/state/now.md` (what this stage touched + which decisions it maps to).
   A repo whose commit messages are all `no message` has a history you can search by time but not by content — the same as not keeping one.

## 2. Decisions and records

4. **Decision numbers have exactly one allocation point**: "next available number" at the top of `ai/decisions/index.md`, **whoever takes one increments it**.
   On a collision: **the one written later changes its number**, leaving a line in place — "was ADxxx, renumbered to ADyyy after a collision"; the one already referenced in several places doesn't move.
5. **Same for task numbers**: "next available task number" at the top of `ai/tasks/index.md`.
6. **Every sentence the Requester says goes into the inbox first** (`product/requirements/inbox.md`), recorded the same round, **and cleared to zero before the round ends**.
7. **Lay out business trade-offs as multiple choice for the Requester's final call**, don't ask open-ended questions. For small things, go with the recommendation, record a decision, and mark it `called on his behalf`.
8. **Verbal agreement goes into a document the same round**: what was said in conversation goes into the inbox or the verbatim directory that round, don't keep it only in your head.
9. **Every stage's wrap-up must update the decision's "implementation" column**: delivered writes "landed + measured (stage N)"; half-done states which half, and which task holds the other half.
   Don't use one cell as the progress of a summary row that covers several sub-items. **Not updating it means nobody can tell what's left.**
10. **Propagate a change down the whole chain**: code → comments → external docs → requirement/feature list → decisions → `state/now.md`. Miss one link and someone starts next stage from the old doc.

## 3. Implementation discipline (**fill in for your project**)

> This section is project-specific. Write what you **actually agreed on**, don't copy generic software-engineering dogma —
> an entry with no incident behind it goes unread three months later. Directions to consider:

11. `<hard constraints on technology choices, e.g. "the backend uses the standard library only", "no third-party UI framework">`
12. `<real implementations, no mocks; a missing component honestly returns an empty state>`
13. `<which table a new interface/config item must be registered in>`
14. **Self-review the interaction loop**: before handing off, check that every state is complete (enter/exit/empty/error/first-use),
    that there are no extra elements (duplicate titles, unusable controls — delete them on the spot), and that no element is missing. **The Requester says 1; on interaction you think of 10 yourself.**
15. `<comment conventions: language, what a file header must say>`

## 4. Front end / interface (**fill in for your project; no interface means delete the whole section**)

16. `<which file is the one source of style tokens; new code may not hardcode colors or numbers>`
17. `<controls of the same kind share one style system-wide; look for an existing control to reuse before making a new one>`
18. `<the "changed it, no effect" holes such as caching and version numbers>`

## 5. Pre-delivery self-check (**fill in for your project**; missing one means it isn't done)

> **This is the most important section**: it defines what "done" means.
> Every entry should **come out of one command**, with no human judgment. Paste the raw output into `claude-outputs/developer/`.

| # | What to run | Which incident left it |
|---|---|---|
| 19 | `<build>` | `<has a file that doesn't compile ever sat in the repo?>` |
| 20 | `<static analysis>` | |
| 21 | `<tests>` | |
| 22 | `<checks specific to this project, e.g. syntax scan / path reconciliation / rule lint>` | |

**Beyond the checklist there is the "self-test"** (`ai/roles/developer.md` §5b): **walk through the feature you built once as a user yourself** —
go item by item through the task's "Acceptance"; for UI, **compare one-to-one against the finalized prototype** (colors from tokens, icons taken as-is, the four states empty / loading / error / disabled + narrow screen + dark mode), and paste screenshots into the report;
click through the other callers of any shared dependency you touched; rerun the original reproduction steps for every bug you fixed.
**A machine self-check cannot prove "this feature works"**; that part only a human can walk. A self-test does not replace review — **you can't test your own blind spot**.

**Two more beyond the checklist, equally unskippable**:

- **Verify on the real machine / in a real environment**, not "it should run". **A unit test that only covers pure functions is no test at all** — if you're going to test, test down to the layer where it is actually called.
- **A newly added guard script or guard test must be run once on the spot against a deliberately broken case, with the output showing "it did go red" pasted into the report.**
  A guard incapable of a reverse assertion gives false safety, which is more dangerous than no guard.

**There is one the other way round too: a guard needs a reverse assertion (break something and watch it go red), a positive test needs a pre-assertion (prove first that you really are testing it).**
Two sides of the same point — **green has to mean something**.
**"I did not reproduce it" is a conclusion only when the pre-assertions are all green**; otherwise it is just "my rig never came up".
- **A guard must judge the thing it is protecting, not that thing's textual shadow.**
  The same thing can be written in endless textual shapes, and all you can block are the few you thought of.
  **If it can be executed, execute it once and look at the result** (load it in a sandbox, start a process, send a real request); fall back to text matching only when it can't be,
  and write down "which forms it cannot catch".
  **A real case**: to guarantee "the module injects styles on load", three textual criteria were tried in turn — counting braces, adding a marker comment, judging by position —
  and the three were broken through by braces inside a template string, by a human forgetting the marker, and by the file structure respectively;
  switching to actually loading the module in a sandbox and looking at the result catches even the form all three textual criteria missed.

## 6. Guards you run often (shipped with the template, usable out of the box)

| Script | What it checks |
|---|---|
| `ai/check-links.sh` | Paths in docs that point at nothing. **Broken links must be 0** |
| `ops/verify/check-paths.sh` | Hardcoded machine IPs and retired old directory names in scripts/docs |
| `ops/verify/check-inbox.sh` | Whether the inbox still holds unhandled Requester statements. **Must be zero before the round ends** |
| `ops/verify/check-bugs.sh` | Whether the bug loop is broken: were reproduction steps actually written, was there a retest after the fix, does the close have evidence. **Must be green before the round ends** |
| `ops/verify/check-ledger.sh` | Whether the task fields are complete, **whether the state double write agrees**, **whether one ID has a second file**, whether index and entities line up, whether there are loose files in the `ai/` root |
| `ops/verify/check-writeback.sh` | Whether `tmp/writeback-pending/` still holds changes never written back to the repo |
| `ops/verify/check-mail.sh` | Whether **the seat mail** has rotted: unread only · fields filled · nothing stale (>7 days) · no duplicate letters · no sender piled up past 3 · no work handed out through the mail · the archive is one file per seat per month |
| `ops/verify/check-root.sh` | **Every item at the repo root (file or directory) is in the §1 list in `layout.md`**, no legacy name has come back as a real path, and every first-level entry under `claude-outputs/<seat>/` carries a date (not retroactive: gated on the git add time) | Every wrap-up; **always after creating something at the repo root** |
| `ops/verify/check-mirror.sh` | **The front-end source and its prototype mirror match line for line** (§4.22 had no script watching it, and 9 files had already drifted on HEAD). Pre-existing drift lives in `ops/verify/.mirror-baseline`, which **may only shrink** | After changing the front-end source; every wrap-up |
| `ops/verify/check-css-namespace.sh` | **Within one page, two files may not each define the same top-level single-class selector and override each other** (the root cause of B-0003: an injected bare `.spin` overrode the chat side's `.spin`) | After changing a module in `web/` that injects CSS |
| `ops/verify/check-all.sh` | **Runs every one of the above in one go and answers with one table** (run it when the Requester says `conformance sweep`) |
| `ops/verify/check-budget.sh` | Whether the line-count budgets are exceeded, and **how many lines the opening read really is**. **Relaxing a limit = changing the rules, and goes into the maintenance log** |
| `ops/verify/check-filenames.sh` | **Filenames that cannot be created on Windows** (`<>:"\|?*`, trailing dot or space, reserved names, two names differing only in case) |
| `ops/verify/check-entrypoints.sh` | Whether other platforms' entry files (`AGENTS.md` and the like) have turned into a second set of rules. **The only real entry point is `CLAUDE.md`** |

## 7. Delete what should be deleted, update what should be updated

**Repos rot because nobody dares delete.** The "let's keep it for now" things are a garbage mountain nobody dares touch a year later.

| When you hit | Do |
|---|---|
| This stage's temporary files in `tmp/` | **Delete them at this stage's wrap-up**, don't leave them to the next |
| A second copy of the same thing | Keep one, **delete the other**, and record in a decision which one you kept and why |
| A rule, reference or script line pointing at a directory/file that no longer exists | **Delete it outright**, don't comment it out and keep it |
| Dropped specs, superseded decisions | **Move them into `archive/`** (this kind is "archive, don't delete" — they are historical evidence) |
| A doc paragraph that is outdated but still holds | **Update it**, don't write a new paragraph next to it |

**The criterion**: before deleting, ask "does its information exist anywhere else" — yes (version control, a live file, archive) means delete; no means make it exist first, then delete.
**Deleting isn't destruction; keeping a pile nobody maintains is.**

## 8. Files and directories

23. **When you move a file or change a directory, rescan every path that references it that same round**, and run `ai/check-links.sh` (broken links must be 0).
24. **No second copy of a script with the same name.** Deployment and ops scripts go only in `ops/scripts/`; self-check scripts that travel with the source go in `src/<project>/tools/`.
25. **Nothing in `tmp/` may be referenced by any formal file.**
26. **Machine information lives only in `ops/machines.json`, in-repo paths only in `ops/paths.ps1`**; nowhere else may hardcode them.
