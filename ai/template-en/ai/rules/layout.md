# Directory rules · where things go

> **Master principle: sort by "does this thing have a lifecycle", not by "who wrote it".**
> Stateful, referenced over and over, co-written by several roles (tasks/decisions/specs/requirements) → their own fixed directories;
> one-off and belonging to one role (reports, screenshots, measurements, research) → `claude-outputs/<role>/`;
> material all three parties need to see → `claude-outputs/shared/`.
>
> **One thing has exactly one home.** In this structure, no category of thing can go in two places.

## 1. Top level

| Directory | What goes in | Who writes | Committed |
|---|---|---|---|
| `CLAUDE.md` | Identity command words + the hard laws in one line each + the directories at a glance | **Maintainer** | ✓ |
| `README.md` | Project intro for humans | Reviewer | ✓ |
| `FRAME-Development-Model.md` | The outward-facing description of this development model (how the four powers work) | **Maintainer** | ✓ |
| `AGENTS.md` and other alias entry points | **One line of signposting only, pointing at `CLAUDE.md`**. Other AI platforms load them automatically; **not one word of the content may be copied across** (two entry points will diverge with no symptom) | **Maintainer** | ✓ |
| `ai/` | Everything about the three roles working together | AI | ✓ |
| `product/` | Product definition: vision · requirements (inbox/verbatim/spec/formal) · **design and prototypes (finalized; development recognizes only this)** · **development plan and milestones** | Requester + AI | ✓ |
| `docs/` | Engineering docs: architecture · directory notes · feature list · operations · ISO | AI, humans read it too | ✓ |
| `src/` | Source. **Inside `src/<project>/`, organize by that language's or framework's own official convention; this template does not govern the inside** | Developer | ✓ |
| `ops/` | Deployment and ops scripts · verification scripts · systemd units · **`machines.json`, the test-machine list** · **`paths.ps1`, the one place paths are defined** | Developer | ✓ |
| `dist/` | Build artifacts (binaries, upgrade packages, ISO) | The build | ✗ gitignore |
| `claude-outputs/` | Claude's scratch area (see §4) | AI | ✓ |
| `archive/` | History no longer maintained; things go in, never out | — | ✓ |
| `tmp/` | Temporary, emptied every stage | Anyone | ✗ gitignore |

### Who changes `docs/`: whoever it blocks changes it on the spot

`docs/` is engineering documentation (architecture, directory notes, operations, the real-machine chain), and **all four seats may read it and all four may be blocked by it**.

**Rule**: **whoever works from the doc and finds the doc wrong fixes it on the spot**, and records a line under "don't step on this again" in `ai/state/now.md`.
**Don't open a task and wait for someone else to fix it** — the next person falls into the same hole, and opening a task costs far more than changing one line.

Two things when you change it: ① **actually run it once** to confirm the new wording is right (**commands in docs are code too**); ② say in the report or the maintenance log what you changed.
**This does not apply to `ai/rules/` or `ai/roles/`** — those two belong to the Maintainer seat; if you find a problem, tell the Requester to pass it to the Maintainer seat.

### Committed and not committed: only two directories are not committed

**`tmp/` and `dist/`, those two. Everything else is committed.**

- Need a one-off file or directory → make it in `tmp/`; build artifacts → `dist/`.
  **Don't make it somewhere else and then come back and add a `.gitignore` rule** — that is exactly the process that grew six `_to_delete/` directories (17MB / 109 files) last time.
- **Don't confuse "one-off" with "produced in passing"**: the Supervisor's proposals, review records, real-machine screenshots and measured data **look like one-off output but must be committed**,
  they are the evidence for a later re-check; whereas what the packaging and release process generates **looks important but is useless once used**, and can be rebuilt any time.
- Copies of old files go **nowhere** — git has them all (`conventions.md` §1).
  **The one exception is the initialization migration's snapshot** `archive/legacy-<date>/` — the old project may never have been in git at all,
  so git can't get it back and that one copy stays (`docs/guide/project-init.md` §3.4). That is the only exception.

## 2. Inside `ai/`

| Directory | What goes in | Who writes | Who reads |
|---|---|---|---|
| `index.md` | The whole-project map | Maintained by the Maintainer | Every session, and only this one |
| `roles/` | The three role handbooks | Reviewer (after the Requester's final call) | **Each role reads only its own** |
| `rules/` | laws · conventions · workflow · layout + **maintenance-log** (the maintenance log) | **Maintainer** | All four read laws, the rest as needed |
| `tasks/` | One file per task + `index.md` + `archive/` | **Developer and Reviewer write the same file** | Read only your own entry |
| `decisions/` | The AD ledger: `index.md` (where numbers are taken) + 7 number-range files + `archive/` (the original old ledgers) | Whoever makes the call records it | To look one up, read one number-range file |
| `specs/` | Technical specs. **Once settled = required reading before you start, and updated as the implementation moves** | Reviewer drafts / Developer adds measurements | Read whatever the task's `spec` points at |
| `state/` | `now.md` (what it looks like now, ≤200 lines) + `archive/` (the chronicle, not read by default) | Developer updates it at every stage's wrap-up | Getting a new session up to speed |
| `mail/` | **Seat mail**: twelve `to-<recipient>/from-<sender>.md` files (**unread only**) + `archive/<seat>-<YYYY-MM>.md` (moved in once handled, **one per seat**) + `README.md` (how to send and read) | **Whoever sends writes it; the receiving seat moves it out once handled** | **Each seat reads only its own at the opening** |
| `template/` | **The generic copy for starting a new project**: this structure with the project-specific content stripped out | **Maintainer** (syncs the same round the rules change) | Copy the whole thing when starting a new project |

## 3. Size budgets (over the limit means split it; hard constraint)

| File | Limit | What to do when over |
|---|---|---|
| `CLAUDE.md` | 100 lines | Move the details into `ai/index.md`. **Raised from 80 to 100 on 2026-09-15**, reason: a fourth seat + command words going from 3 to 8; the directory table and the wrong-seat detail have already been moved out |
| `ai/index.md` | 80 lines | Move the details into that directory's `index.md` |
| `ai/roles/developer.md` | 160 lines | Move the details into `workflow.md` / `investigate.md` / `docs/` |
| `ai/roles/reviewer.md` | 230 lines | It carries both testing and design. **Pulled back from 300 to 230 on 2026-09-15** — last time it was "duties grew, so widen the ruler"; this time whole sections really were moved out |
| `ai/roles/supervisor.md` | 100 lines | It should be the shortest of them all anyway |
| `ai/roles/maintainer.md` | 220 lines | **Relaxed from 150 to 220 on 2026-09-15**: it gained §3a (spot a working-method remark and propose it as a rule) and §3b (the four-seat cross-check), **and it is not in anyone else's opening read** (only the Maintainer reads it) |
| `ai/rules/maintenance-log.md` | One line per entry | At 50 entries, move them into `archive/` |
| `ai/memory.md` | **80 lines** | **Project memory** (information in constant use · a specific situation handled a specific way · fixes you worked out yourself). In the opening read, so it has to be short; when it is full, move the paragraphs into `docs/`. **About half the cap is the "what to record and what not to" criterion** — delete the criterion and this file grows into a junk drawer. **Relaxed from 55 to 80 on 2026-09-15**: 55 held the criteria but no entries, and a memory that cannot hold entries is not a memory |
| `ai/mail/to-<recipient>/from-<sender>.md` | **12 lines** | **Seat mail, unread only** (about 6 letters). **One file per sender** — only once the drop-box is split this far do the four seats really stop touching the same file (**changed on 2026-09-15 from "one file per seat, 30 lines"**, because three senders appending to the end of one file means a git conflict sooner or later). Full does not mean raise the cap; it means **nobody reads it or the letters are too fragmented**. It is in all four seats' opening read: three files of 12 lines is 36 at worst, so the most expensive opening read stays at most 659 and **the 660 hard cap does not move**, and the "no sender piles up past 3 non-notice letters" guard fires well before that |
| `ai/mail/archive/<recipient>-<YYYY-MM>.md` | No limit | Append only, with the outcome. **The archive belongs to the recipient** (a letter belongs to whoever it was sent to; the sender archives nothing). **One file per seat per month** — **each seat writes only its own, no two seats touch the same file, and that is what keeps git conflicts away** (pointed out by the Requester on 2026-09-15). Nothing to delete |
| `ai/mail/README.md` | **150 lines** | How to send and read, what does not belong in the mail, **one round trip is the limit**, **look at the other mailbox before sending**, **read it all and de-duplicate**. **Not in the opening read** — read it when you are about to send. **90 → 120 → 130 → 150 on 2026-09-15** (the last step made room for the table "what may and may not be mailed between the Developer and Reviewer seats" — **the boundary the Requester cares about most: mailing it pulls the development trail out of the ledger**): first the Requester added three boundaries on the spot (no reply loops · no courtesy receipts · no flooding, plus read-all-and-de-duplicate), then two more red lines **bought with real incidents** (**look inside before moving or deleting** · **another seat's live file may only be appended to**). **Those five are the reason the mechanism holds**, and it is **not in the opening read**, so a longer file costs the four seats nothing |
| `ai/rules/requester.md` | 130 lines | **How to deal with the Requester** (the pop-up choice control · do not just do as told · he told the wrong seat). Not in the opening read — **read it when you are about to talk to him** |
| `ai/rules/investigate.md` | **140 lines** | **Generic investigation method** (both the Developer seat and the Reviewer seat read it). Not in the opening read — **read it the moment you get an "it's broken"**. **Set at 100 on 2026-09-15, relaxed to 140 on 2026-09-16**: two generic criteria **bought with real incidents** were added — "a test assertion is not proof of intent" (the Reviewer seat got it wrong twice in a row) and "the two sentences of a reverse assertion" (the Developer seat hit one failure variant per round). Neither belongs to a single seat (the Developer writes the tests, the Reviewer re-checks them, the Maintainer reverse-asserts the guards themselves), and cutting them would delete "how to show a test is biting anything at all". **It is not in the opening read**, so a longer file costs the four seats nothing |
| `ai/rules/conventions.md` | **200 lines** | Merge similar entries, or move a whole section into `specs/`. **Relaxed from 150 to 200 on 2026-09-15** — it is **not in the opening read**, it is a reference looked up on demand; the rule is "move the details in here, don't stuff them into the role handbooks and `CLAUDE.md`", so it has to be given the room |
| `ai/rules/workflow.md` | 380 lines | The biggest file in `rules/`, and **at the Supervisor seat's audit it was 459 lines while this table gave it no budget at all**. Over the limit, move a whole section out (the bug section has already moved into `ai/bugs/README.md`) |
| `ai/rules/layout.md` | **240 lines** | Over the limit, move one of its sections into `conventions.md`. **It is not in the opening read**, and the budget table plus the **file-ownership table** (§10) already make up most of it. **Relaxed from 210 to 240 on 2026-09-15**: §10, the ownership table (22 lines), is the **single source** for `commit-round.sh --seat` and for deciding whose red a red is — **moving it out would make the script keep its own copy**, exactly the trap the budget table fell into once |
| `ai/bugs/README.md` | 120 lines | The full procedure for a bug; the index is in `index.md` |
| `ai/tasks/index.md` | 100 lines | Move `passed` entries older than 3 stages into `archive/`. **It grows with the project; over the limit the answer is archiving, not deleting lines** |
| `ai/bugs/index.md` | 80 lines | Move `closed` entries older than 3 stages into `bugs/archive/`, but **keep the regression list** |
| `ai/bugs/B-*.md` | **180 lines** | Growing past it means two bugs are mixed into one. **Relaxed from 100 to 180 on 2026-09-15**: 100 was estimated **before** the "Locating" section was given its three mandatory subsections (can it be reproduced locally / the elimination tree / conclusion or current hypothesis); with the four reproduction items and a retest per round, a bug investigated properly is simply longer than a task |
| `ai/tasks/T-*.md` | 150 lines | Too long means it should split into two tasks |
| `ai/decisions/index.md` | 100 lines | The details are already in the number-range files; it shouldn't grow |
| `ai/decisions/AD####-####.md` | 100 entries per range | The ranges are fixed; it won't grow |
| `ai/state/now.md` | **140 lines** | Move stale paragraphs into `archive/`. **Tightened from 200 to 140 on 2026-09-15** — it is read in **every one of the four seats' openings**, the second most expensive file in the opening read; the cap was tightened to make room for the "how to investigate" section |
| `ai/specs/<name>.md` | No limit | But **it must have a file header** (see §5) |
| `product/plan/roadmap.md` | 80 lines | One milestone per line; the detail lives in `milestones/` |
| `product/plan/milestones/M-*.md` | 150 lines | Growing past it means it should be split into two milestones |

**Why there are budgets**: in the old structure four "live files" added up to 1.78MB, and any session that read two of them burned hundreds of thousands of tokens.
🔴 **Relaxing any one of these limits = changing the rules.** It goes into `ai/rules/maintenance-log.md` as an entry
stating **what it was before and after, why, and what was moved out**. **"The duties grew, so we widened the ruler" is not a reason** —
that is the budget not existing. Guard: `bash ops/verify/check-budget.sh` (it reads the numbers out of this table, it does not keep its own copy).

**The cost that actually matters is the total opening read**, whose hard cap lives in `ops/verify/check-budget.sh`,
which computes it from the **real line counts** and takes no document's word for any number — **these three places used to state three different numbers**.

> **Anything added to the opening read has to say first what it pushed out**; generic method goes in `ai/rules/`, with one line of signposting in each of the four seats.

**Budgets aren't fastidiousness, they're cost.** For how many lines the opening read is, run `bash ops/verify/check-budget.sh` and look at the current measured value.

### 🔴 Only the Maintainer seat may change the rules — anyone else who spots something **tells the Requester to pass it on**

**Of the four seats only the Maintainer seat may touch these**: `ai/rules/*`, `ai/roles/*`, `CLAUDE.md`, the directory rules, the guard scripts, both templates.

| You are | You spot "a rule should be added here / this hard law is wrong / the guard misses a case" |
|---|---|
| Developer · Reviewer · Supervisor seat | **You don't change it yourself; the way to change it is to send mail**: `ai/mail/to-maintainer/from-<your seat>.md` (symptom + evidence + proposed fix + cost; anything longer than three lines becomes `claude-outputs/<your seat>/<date>-<topic>.md` and the letter carries only the path). **No need for the Requester as a transport**, and **leaving it in a task or report does not count as passing it on** (`ai/rules/requester.md`). **The test: is this suggestion "the thing this task is there to solve"? If not, mail it** |
| Maintainer seat | Only act after the Requester confirms, record it in `ai/rules/maintenance-log.md`, **sync both the Chinese and the English template in the same round** |

**The only exception is `docs/`**: whoever works from a document and finds it wrong **fixes it on the spot** (the one in §1 of this file).
`docs/` is engineering documentation, not rules.

> **Why it is locked down this hard**: the rules are the coordinate system the four seats share. **If any one seat can move the coordinate system unilaterally, the other three drift without knowing it** —
> and that drift has no symptom at all, until two rounds later someone finishes a piece of work on the new coordinates and someone else reviews it on the old ones.

### `CLAUDE.md` costs you once per session, so it **multiplies**

`CLAUDE.md` **is loaded once every session**, so a line you add costs "one line × every session you have ever opened".

**The criterion is one sentence**: **only what you would go wrong without goes into `CLAUDE.md`**; everything else goes into `ai/rules/` or a role handbook,
with a single pointer line left in `CLAUDE.md`.

| Goes in | Stays out |
|---|---|
| The identity command table (without it you don't know who you are) | The full detail of any one rule |
| The commands in daily use (without them you can't get started) | Examples, backstory, incident write-ups |
| The one-line version of the hard laws | The directory listing (that is `ai/index.md`'s job) |
| Directions like "raise everything with the Reviewer seat only" | Any one seat's own procedure |

**Guard**: `bash ops/verify/check-budget.sh` watches its line cap; **relaxing the cap = changing the rules, and it goes into the maintenance log**.

### Which language names use: **directories always English, content deliverables follow the Requester**

| What | Which language | Why |
|---|---|---|
| **Every directory name** | **English, always** | The structure has to work across languages; the guards, the indexes and cross-project reuse all depend on these matching. **Unless the Requester asks otherwise, or built the directory himself** |
| **Structural files** (`CLAUDE.md`, `README.md`, every `index.md`, the rules and role handbooks, scripts, config) and **IDs** (`T-####` `AD####` `B-####` `M-##`) | **English / digits, always** | They are the skeleton and the search keys, not the deliverables |
| **Content deliverables** — technical specs, database design, explanatory docs, requirement specs, reports: **filename and contents** | **The working language the Requester chose** | **A filename is how a human finds things.** He has to recognize "which one is the VPN spec" at a glance in a file browser; an English abbreviation does not do that |

🔴 **A placeholder directory may not use angle brackets**; use a form like `_PROJECT_`. `<>:"|?*` are **illegal filename characters on Windows**,
and the AI mostly runs on Linux — **where they can be created, with no symptom at all**, right up until the Requester opens a GUI client on Windows and it blows up
(a real one: SourceTree reported `Invalid argument`). **Writing `<project>` in prose is correct**, that is a placeholder in text, not a real directory.
Guard: `bash ops/verify/check-filenames.sh`.

🔴 **When you move, promote or archive a file, it keeps the name it had.**
**Never "normalize" it to an English abbreviation on the way past** -- that swaps a name the Requester knows for a code only you know.
Renaming needs his nod.

> **A real one**: in one structure migration, 32 documents under the technical-spec directory were all renamed to short English slugs.
> Making the *directories* English was the Requester's decision; making the *filenames* English was not -- whoever moved them did it on their own.
> The result was that the Requester could not tell his own specs apart. **They were all restored later from the original paths recorded in each file header**,
> which shows the other half of the lesson: **writing the original path into the file header when you move something can save you.**

## 4. `claude-outputs/` — Claude's scratch area

| Subdirectory | What goes in |
|---|---|
| `developer/` | Raw self-check output, measured data, delivery notes |
| `reviewer/` | Review records, work orders, write-ups of real-machine feedback, verification records for the Supervisor's output |
| `supervisor/` | The Supervisor's reports, proposals and research — **committed as-is, nobody changes a character** |
| `shared/prototype/` `shared/screenshot/` `shared/measurement/` | Material all three parties need to see |

**It is a scratch area, not a second formal directory.** Once something is adopted it must **move to where it belongs** —
where each thing moves is listed item by item in the "promotion table" in `claude-outputs/README.md`; follow it when you adopt something.
Evidence such as screenshots and measurement output **is not promoted**; it stays here forever and the task file references it.

## 5. The file header every spec file must have (it is what makes "settled = required reading before you start, updated continuously" hold)

```
---
status: proposed | settled | dropped (superseded by xxx)    ← only these three, don't invent
version: v1.3
last updated: 2026-09-16
decisions: AD<number>, AD<number>
referenced by: T-0001, T-0003
---
## Change log
| Date | Version | What changed | Who |
```

Four rules:

1. **A task's `spec` must point at a spec or an AD**, never just "as we said last time".
2. **Whoever changes the implementation changes the spec**, finished inside the same stage. Implementation and spec out of sync with the spec untouched means someone starts next stage from the wrong one.
3. **`referenced by` goes both ways**: the task names the spec, the spec names which tasks use it.
4. **A spec does not record "how far the implementation got"** — that's the job of the task and the AD implementation column. A spec only says "how it should be done".
   **Dropping is not deleting**: change the file header, move it into `specs/archive/`, and leave a line in the dropped table in `specs/index.md` pointing at the one that supersedes it.

## 6. Explicitly not allowed

- Loose files at the root of `ai/` (only `index.md` and `check-links.sh` live there).
- **Changing a role handbook or `rules/` without syncing `template/`** — once the template falls behind, the next new project starts out from outdated practice, and there is no symptom at all. Guard: `ops/verify/check-template-sync.sh`.
- A second copy of a script with the same name (there were once three `push-web.ps1`, each with different contents).
- Putting self-check logs, screenshots or temporary files into `ai/tasks/` or `ai/decisions/`.
- Referencing anything from `tmp/`.
- **Pointing a task file at a spec or a design draft in `claude-outputs/`** — that is the scratch area, and pointing there means development works from something that isn't finalized.
  Promotion paths: see the two § subsections in `claude-outputs/README.md`.
- **Hardcoding a test machine's IP in a doc or a script** — test machines come and go and IPs change; the one source is `ops/machines.json`, referenced by `id` (measured: one IP appeared 124 times in the old repo).
- **Hardcoding an in-repo path in a script** — use `$Src` / `$Dist` / `$Tmp` / `$Outputs` from `ops/paths.ps1`.
- Creating a second "to-do" or a second "handover". **To-do = `ai/tasks/index.md`, handover = `ai/state/now.md`**, and nothing else.
- Stacking copies of old files stage by stage — get old versions from git (`conventions.md` §1).
## 7. File ownership: **commit only your own; a red belongs to whoever owns the file**

**This table is the single source**: `ops/scripts/commit-round.sh` reads ownership from here (same rule as the budget
table — **never keep a second copy inside a script**), and `conformance sweep` uses it to decide whose red a red is (`CLAUDE.md` §2).

| Path (prefix or glob) | Owner |
|---|---|
| `CLAUDE.md` · `AGENTS.md` · `README.md` · `FRAME-Development-Model.md` | Maintainer seat |
| `ai/index.md` · `ai/glossary.md` · `ai/frame-manifest.txt` · `ai/check-links.sh` | Maintainer seat |
| `ai/rules/*` · `ai/roles/*` · `ai/mail/README.md` | Maintainer seat |
| `ai/template/*` · `ai/template-en/*` | Maintainer seat |
| `ops/verify/*` · `ops/scripts/*` · `ops/README.md` · `docs/guide/*` · `claude-outputs/README.md` | Maintainer seat |
| `ai/tasks/*` · `ai/bugs/*` · `ai/decisions/*` · `ai/specs/*` · `ai/state/*` | Reviewer seat |
| `product/*` · `claude-outputs/reviewer/*` | Reviewer seat |
| `src/*` · `dist/*` · `claude-outputs/developer/*` | Developer seat |
| `claude-outputs/supervisor/*` | Supervisor seat |
| `ai/memory.md` · `ai/mail/to-*` · `ai/mail/archive/*` · `ops/machines.json` · `docs/ops/*` | **shared** (all four seats write) |

🔴 **Commit only your own** (`ops/scripts/commit-round.sh --seat <seat>`).
**Measured twice**: with `git add -A`, commit `acf7217` swept 10 files the Reviewer and Supervisor seats were editing at that
moment into the Maintainer's commit message; half an hour later the Reviewer's commit `992ed79` nearly swept 6 files the
Maintainer had staged. **This is not a fluke, it is the default behaviour.**
So the script now **stops when the changes span more than one seat**, lists which files belong to whom, and lets you
commit only yours with `--seat`, or deliberately commit everything with `--all-seats`.

