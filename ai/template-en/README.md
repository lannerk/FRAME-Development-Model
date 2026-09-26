# FRAME — the four-role AI development model

> **Four-Role · Audited · Maintained · Evidence-based**
>
> A **directory structure + four role handbooks + a set of guard scripts**.
> Not a framework. Nothing to install, no dependencies.
> Copy it into a repo, open a few AI sessions, say one word to each, and it starts running.

> 🧭 **If you are starting a project from this template**: during initialization this `README.md`
> gets replaced by **your project's own** (`docs/guide/project-init.md`, step 4). The full write-up
> of the method itself lives in **`FRAME-Development-Model.md`** at the root — keep a line in your
> new README pointing at it.

---

## 1. What this is

The expensive part of having an AI write code was never "getting it to write something". It is
**getting it to write something reliable, that someone can still pick up a month later**.

FRAME's answer: **move the collaboration state out of the conversation and into files, then split
the one who writes from the one who judges into separate sessions.**

```
You (the Requester)
   │  you talk to exactly one of them
   ▼
Reviewer ──opens a task──▶ Developer ──reports──▶ Reviewer rules pass/reject ──▶ local git commit
   ▲                                     │
   │  consulted on demand                └─▶ decision ledger / bug ledger / current state
Supervisor (independent advisor)   Maintainer (owns the rules, touches no work)
```

Four sessions that **never talk to each other directly** — everything is handed over through files
in the repo. Any session can be closed and reopened at any time: **the context is not in the
conversation, it is in the files.**

---

## 2. What it solves

None of these are hypothetical. They are what one real project walked into, one at a time:

| Symptom | Why it happens | What FRAME does |
|---|---|---|
| Every new session needs the background re-explained; it gets more expensive the longer you talk | The context only lives in the conversation | **A fixed opening read** (with line budgets a guard enforces); everything else on demand |
| Docs grow to megabytes and burn six figures of tokens just opening | Nothing says how big a file may get | Every file has **a reason to read it and a line cap**; `check-budget.sh` judges **real line counts** |
| The same item has four different statuses in four to-do lists | Anyone can start another list | **One to-do list, one handover file**; `check-ledger.sh` judges whether **the double write agrees** |
| The ledger says "to build" for things shipped weeks ago | Nobody backfills at wrap-up | A mandatory wrap-up checklist, plus a guard |
| The AI says "fixed" and the real machine still fails | "Looks fine to me" gets treated as a conclusion | **Every conclusion carries evidence**: source line numbers / measured numbers / official docs — one of the three |
| You add a self-check script and the script itself is broken | Nobody ever checked that the guard can go red | **Reverse assertion**: a new guard must be deliberately broken once, and the "it really did go red" output pasted into the report |
| The same AI finishes and declares its own work fine | The writer and the judge are the same one | **The writer and the judge are two sessions**; the judge does not carry the assumptions that produced the code |
| A bug gets paraphrased once and development fixes a different problem | Only the symptom was passed on, not the conditions | A bug must carry **environment / preconditions / steps / symptom** — missing one, it may not go to development |
| The rules and what people actually do drift apart | Everyone uses the rules; nobody tends them | **A fourth seat tends them**: changing one means recording it, syncing the template, and opening fresh sessions to verify the other three really comply |

> That last row is the biggest difference between FRAME and a typical "AI collaboration convention":
> **it assigns someone to the rules themselves.** Without that seat, any set of conventions decays
> within a few months into a document nobody follows.

---

## 3. The four seats

| Seat | Authority | What it does | What checks it |
|---|---|---|---|
| **Developer** | Execution | Implement features *reliably*; **self-test before submitting for review** | The Reviewer can reject it — but it may rebut with evidence |
| **Reviewer** | Review | Set the standard, rule pass/reject, schedule work, take requirements; **doubles as professional tester and architect** | The Requester can overrule; the Developer can overturn it with evidence; **disputes can go to the Supervisor on demand** |
| **Supervisor** | Oversight | Independent survey, answerable directly to the Requester, off the development mainline | Its opinions enter the queue only after the Reviewer verifies them |
| **Maintainer** | Rule-making | Maintains the model itself: rules, handbooks, templates, guards | Moves only once the Requester confirms; **takes no part in development, touches no requirements** |
| You (the Requester) | Final call | Set direction, make the trade-offs | — you are where the authority comes from |

**Order of precedence**:

```
The Requester's call  >  a fact the Reviewer verified  >  the Supervisor's opinion  >  anyone's "I think"
Who decides the rules themselves  →  the Maintainer (after the Requester confirms)
```

**One hard rule**: the rules, the role handbooks, `CLAUDE.md` and the guard scripts are
**the Maintainer's alone to change**. Any other seat that spots something **sends a letter to
`ai/mail/to-maintainer/from-<its own seat>.md`** (mail carries talk, the ledger carries work) —
**the Requester is not needed as a transport**. (The one exception: `docs/`, engineering documentation —
whoever is blocked by it fixes it on the spot.)

### An extra seat: the Researcher (the R&D line)

🔴 **The four-power structure is unchanged — the Researcher has a seat but not one of the powers**:
until the Supervisor or the Reviewer has verified it, its output carries the weight of "I think" and sits at the **very bottom**
of the order of precedence above. It is not part of the checks and balances; what checks it is **the Requester**
and **falsifiable experiments**.

It works on an **R&D line that runs alongside development**, taking an idea that does not have a name yet to a
project that can be started: the directory `ai/RandD/`, the command word `researcher`, the handbook
`ai/roles/researcher.md`, the guard `check-randd.sh`, and **graduation** as its end point (nine criteria green →
the Supervisor verifies → the Requester settles it → the Supervisor migrates it).
**Whether to open this line is the Requester's call, and development is unaffected either way**; leave `ai/RandD/` empty if it is not open.

---

## 4. Quick start

**1. Copy it out**

```bash
cp -r ai/template-en/. ../my-project/
cd ../my-project && mv gitignore.template .gitignore && rm SYNC.md
```

**2. Open one session and make the first sentence "Initialize the project"**
(say it in whatever language you use — **it is recognized by meaning, not by literal words**)

That session recognizes itself as the **Maintainer seat** and follows
`docs/guide/project-init.md`: it asks you for the **project name** and the **working language** as
multiple choice, localizes the docs, walks you through the blanks, and runs the guards at the end.

> **An existing project takes the same route**: copy the template over the old repo's root and it
> will use `ai/frame-manifest.txt` to sort everything into "ours / the old project's / name
> clashes", produce a migration mapping table for you to confirm, then migrate and archive.
> **It deletes nothing on your behalf.**

**3. Open the sessions, one word each**

```
developer        reviewer        supervisor        maintainer
```

Saying nothing means developer. **You talk only to the Reviewer**; it coordinates the rest.

---

## 5. A worked example

You hit a bug while using the thing. From your first sentence to the commit, it goes like this:

**① You → the Reviewer** (the only seat you talk to)

> "Open the settings panel, go back, and the list is empty"

**② The Reviewer**: records it in the inbox (one line per item) → **reproduces it once itself** →
it reproduces → opens `ai/bugs/B-0007-<one line>.md`:

```markdown
---
id: B-0007
severity: S2
source: Requester
status: reproduced
---
## Reproduction (four pieces; missing one and it may not go to development)
- **Environment**: machine `vm-dev` / v0.9.3 / main@a1b2c3d
- **Preconditions**: a signed-in ordinary account, at least 3 rows in the list
- **Steps**: 1. open the list 2. click settings, top right 3. press browser back
- **Symptom**: expected the list intact, actual the whole list blank; console `TypeError: items is undefined`
- **Reproduction rate**: 3/3
```

Then it opens a task `T-0042` carrying `bug: B-0007`.

> **What if it cannot reproduce it**: mark it `to reproduce` and **come back to you for the missing
> conditions** (which machine, which account, which step). **Never dump an unreproduced bug on
> development to guess at** — it will fix a different problem.

**③ You → the Developer**: `review done, continue`

The Developer takes the highest-priority item off the queue itself, reads `T-0042`, **reads
`B-0007` for the conditions to reproduce it**, fixes it, and then:

- **self-tests**: walks the task's acceptance list item by item; anything with a UI gets compared
  **against the finalized prototype one to one** (four states + narrow screen + dark, screenshots)
- writes **`Bugs fixed: B-0007`** in the report and pushes the bug to `fixed, awaiting retest` —
  **it may not mark it closed itself**
- moves the task to `in review`

**④ You → the Reviewer**: `review` (or `review and test` for the full battery)

The Reviewer checks the evidence and runs the guards. **Because "Bugs fixed" is not empty, it must
retest this round** — rerunning `B-0007`'s original steps. **That step does not hang on a command
word.** Only once it passes does the bug move to `closed`.

**⑤ The Reviewer wraps up**:

```bash
bash ops/verify/check-all.sh                       # all nine guards in one run
bash ops/scripts/commit-round.sh "fix: list cleared after returning from settings"
```

The `T-0042` / `B-0007` / decision IDs in the commit message are **harvested from the changed files
and the diff**, not typed by hand. **The script only does add + commit, never push** — pushing is
yours.

---

## 6. The command words

| You say | To | Meaning |
|---|---|---|
| `developer` / `reviewer` / `supervisor` / `maintainer` | a new session | Claim a seat. Saying nothing means developer |
| `researcher` | a new session | Claim the **extra seat** on the R&D line (see §3). Unused while that line is not open |
| `initialize project` (**any language**) | a new session | That session becomes the Maintainer seat and runs initialization |
| `review done, continue` | Developer | Take the highest-priority item off the queue and carry on |
| `review` | Reviewer | Review only: check the evidence, read the code, run the guards |
| `review and test` | Reviewer | Review as usual, **then test everything testable across eight categories** |
| `consult the supervisor on this` | Reviewer | Turn this conclusion into an **advisory task** for the Supervisor seat |
| `look at the task` | Supervisor | Read the one advisory task assigned to it (**its only exception to not reading the queue**) |
| `the supervisor has given its opinion` | Reviewer | Read the Supervisor's output and rule again with it in hand |
| `reload rules` | any seat | The rules changed — **actually read them again** and say what changed |
| `check mail` | any seat | Read `ai/mail/to-<your seat>/`: **read it all at once, de-duplicate, handle each letter**, then move the row into your own archive |
| `conformance sweep` | any seat | Run `check-all.sh` and report one table; **whose red it is follows the ownership table**, and only the Maintainer may change a rule because of it |

---

## 7. What is in the box

| Path | What it is |
|---|---|
| `CLAUDE.md` | **The entry point the AI auto-loads**: identity words, command words, the one-line version of the hard laws. **Deliberately kept short** — it loads once per session |
| `AGENTS.md` | The entry point for other AI platforms: **one line pointing at `CLAUDE.md`** (two entry documents drift with no symptom) |
| `ai/roles/` | Four role handbooks. **Read one and you can start** |
| `ai/rules/` | Hard laws · workflow · directory rules · engineering conventions · **the maintenance log** |
| `ai/tasks/` · `ai/bugs/` | One file per task / one file per bug, each with an index |
| `ai/decisions/` | The decision ledger (ID + evidence + how far it is implemented) |
| `ai/specs/` | Finalized technical specs: architecture · database · tech stack · **how this project is tested** |
| `ai/state/now.md` | **Current state and handover**: where things stand, what not to step on again |
| `product/` | Requirements (verbatim / specs) · design and prototypes · **development plan and milestones** |
| `docs/` · `src/` · `ops/` · `dist/` · `tmp/` · `archive/` | Engineering docs / source / ops and guards / build output / scratch / history |
| `ai/mail/` | **The inter-seat mail**: `to-<recipient>/from-<sender>.md` holds unread letters only, plus one archive per seat. **Mail carries talk, the ledger carries work** |
| `ai/advisor/` | **The kickoff advisor library** (FRAME itself): when he starts a project / raises a large requirement / asks "how should this be done", every seat **thinks the plan and the "why" through for him first and raises the dimensions he never mentioned**. Generic principles · a 53-question bank (each with Why ask and a recommendation) · chains · choice cards · domain practice; **looked up as needed, never read whole, not in the opening read**. What is specific to a project lives in `product/requirements/requester-profile.md` (the profile: private, never flows back). The procedure is `ai/rules/requester.md` §4d |
| `ai/RandD/` | **The workspace of the R&D line** (the extra Researcher seat, see §3): one numbered directory per topic, holding everything not yet settled; empty while the line is not open |
| `claude-outputs/` | The AI's scratch area: screenshots, measurements, reports, supervisor output |

**Inside `src/<project>/`, organize by that language's own official convention** — Go gets `cmd/`
and `internal/`, Maven gets `src/main/java`, a frontend framework gets whatever its scaffolding
generates. **This template does not govern the inside of `src/`.**

---

## 8. The guards

Rules do not run on good intentions; they run on scripts that can turn red.
`bash ops/verify/check-all.sh` runs all of them at once:

| Script | What it judges |
|---|---|
| `ai/check-links.sh` | Paths in the docs that point at nothing |
| `check-paths.sh` | Hard-coded machine IPs and retired directory names |
| `check-inbox.sh` | Anything you said that still has no disposition |
| `check-bugs.sh` | Whether the bug loop is broken: **are there numbered lines under "Steps"**, was it retested after the fix, does a closure carry evidence |
| `check-ledger.sh` | Task fields complete, **whether the double write of status agrees**, index and entities lining up |
| `check-budget.sh` | Line budgets and **the total opening read** (real line counts, not the numbers the docs claim) |
| `check-entrypoints.sh` | Whether alias entry points like `AGENTS.md` are still just pointers |
| `check-writeback.sh` | Anything changed but never written back to the repo, left parked |
| `check-template-sync.sh` | Whether the template kept up (**content fingerprints, not mtime** — mtime does not survive `git clone`) |
| `check-root.sh` | Every entry at the repo root is on the list, no retired directory name has come back, scratch entries carry a date |
| `check-filenames.sh` | File names that cannot be created on Windows (they break cross-platform work on the spot) |
| `check-mail.sh` | The mail has not rotted: unread only · no stale letters · nobody assigning work by mail · one archive per seat per month |
| `check-advisor.sh` | The advisor library has not decayed (**skips itself when there is none**): every choice card has **Recommendation · Why · Does not apply / Reversible** · every question has **Why ask** and **Recommend** · the profile is **seed** (marking it follow pushes his preferences into the open-source repo) · **no private word leaked into anything synced out** |
| `check-randd.sh` | The R&D line's structure and indexes (**skips itself when that line is not open**): an `INDEX.md` in each archive dir · live files within their caps · **nine green criteria before anything may be marked graduated** |
| A few project-specific ones | e.g. frontend cache-busting, source-to-mirror drift, CSS class clashes — **they skip themselves where they do not apply** |

**One design principle runs through all of them**:

> **Judge the thing being protected, not its textual shadow.**
> The same thing can be written an unlimited number of ways in text; you can only block the few
> shapes you thought of. If it can be executed, execute it once and look at the result; fall back to
> text matching only when it cannot, and write down which shapes it fails to catch.

**A new guard must be deliberately broken once** and the "it really did go red" output pasted into
the report — a guard without a reverse assertion gives false confidence, **which is worse than no
guard at all**.

---

## 9. The costs, stated plainly

None of this is free:

| Cost | What it actually means |
|---|---|
| **Several sessions at once** | Four windows open is more work than one |
| **Everything goes through the Reviewer** | You want to tell the Developer "just change this" — you have to tell the Reviewer instead. **What you buy is that nothing gets dropped** |
| **A fixed writing overhead each round** | Update the current state, move statuses, record decisions. **What you buy is that changing sessions costs you no context** |
| **It feels heavy on a small project** | For a tool you finish in a weekend, this is overkill |
| **The rules need tending** | The fourth seat is not decoration; without it, the docs and the practice are two different things within a few months |

**When not to use it**: one-off scripts, a few dozen lines, anything you can finish alone in two hours.
**When it pays**: the project has to survive months, the codebase runs to thousands of lines,
someone else will take it over — or **you have already been burned by "the AI said it was fixed" when it was not.**

---

## 10. FAQ

**Does it work with other AI platforms?**
Yes. `CLAUDE.md` is the only real entry point; every other platform gets a file it auto-loads
(`AGENTS.md`, `GEMINI.md`, `.github/copilot-instructions.md` …) containing **one line pointing at
`CLAUDE.md`**. **Do not copy the content** — two entry documents drift, with no symptom at all.
`check-entrypoints.sh` watches exactly that. The real prerequisite is not the entry file: that
platform's agent needs to be able to **read files, write files and run commands**.

**What about another language?**
`ai/template-en/` and `ai/template/` are the same thing in two languages — **paths identical to the
character, only the content differs**. Initialization asks you for the working language and
localizes the docs. **Careful: some words are read by machines too** (status words, guard markers);
translating one means changing the script in the same pass — the list is in `ai/glossary.md`.

**Do directory names get translated?**
No. **Directory names and structural filenames stay English.** Only content deliverables —
technical specs, database design, explanatory docs — take their filename and content from the
working language. When you move, promote or archive a file **it keeps the name it had**; never
"normalize" it into an English abbreviation on the way past.

**Will the AI committing to git break my desktop git client?**
No. `commit-round.sh` **only does add + commit**: never push, never amend / rebase / reset / force,
never touches `git config`, never switches branch, **never deletes `.git/index.lock`**. If it finds
a lock or an unfinished merge it **exits without touching anything**.

**The rules changed — how do the running sessions find out?**
Say `reload rules` to them. A session has to **actually read the files again** and say **what
changed** — answering "OK" means it did not read them. Newly opened sessions need nothing; they
read the current version on the way in.

---

## 11. How this template evolves

The template belongs to the **Maintainer seat**. Changing one rule means changing three places:
**your project + the Chinese template + the English template**, in the same round, with
`check-template-sync.sh` comparing content fingerprints. What belongs in the template has exactly
one test:

> **Would this still hold on a different project?**
> If yes — ways of working, the split of duties, what each directory is for, traps that generalize —
> it goes in. If no — what the product is, machines and paths, ID numbers, the details of one
> specific incident — it stays out. When syncing, **keep the reasoning, swap the example.**

Every change is recorded in `ai/rules/maintenance-log.md` **together with the Requester's own
words** — so that three months later, "why does this rule exist" has an answer.

## 12. Took this from GitHub? How to keep up with the source

What you hold was **copied out of the source repository's `ai/template/`**, the source will keep
changing the rules, and **you have no commit rights on it** — so syncing has exactly one direction:
**source → your project**. The copy you took **already contains `ops/frame/frame-sync.sh`**; there is
nothing else to install. Three steps to set it up:

```
# (1) clone the source **next to your project**, in the same parent directory
cd <the directory above your project> && git clone https://github.com/<the source>/FRAME-Development-Model.git
# (2) write three lines into your project's ai/frame-repo.conf:
#     role=consumer  /  home=../FRAME-Development-Model  /  push=no
# (3) record the first baseline (your side as it is now, so later source changes count as
#     "the source changed it" -> they get pulled in)
bash ops/frame/frame-sync.sh --adopt-mine
```

Every time you catch up afterwards:

```
cd ../FRAME-Development-Model && git pull && cd -   # pull runs over there: it is a separate repo
bash ops/frame/frame-sync.sh --sync                # reports, writes nothing
bash ops/frame/frame-sync.sh --sync --apply        # write only once you understand it
bash ops/verify/check-all.sh                       # the rules changed, so the guards changed too
```

Two things not to forget:

- 🔴 Write `push=no`. Without it a sync tries to write your changes back into the source
  repository — you cannot push them, so all it does is leave that working tree dirty while you
  believe the sync succeeded.
- 🔴 **Put your own additions in new files** (`ai/rules/ours-xxx.md`); do not edit the ones FRAME
  ships. The mechanism recognizes a new file as yours and never touches it; edit a shipped file and
  you handle one 🔶 every round.

**Several projects**: **one clone of the source is enough** — give each project its own
`ai/frame-repo.conf` (all pointing at that clone) and its own baseline, then sync each project separately.

The details are in `docs/guide/frame-sync.md` §5: the first sync with no baseline · the three ways
out of a fork · projects started from the English template prefix every command with
`FRAME_TEMPLATE=ai/template-en` · how to tell whether you are current · why the source has `push=yes`
and you have `push=no` with no switch anywhere (that conf is **never touched by a sync**).

---

**Full design write-up**: `FRAME-Development-Model.md` at the root
**Initialization procedure**: `docs/guide/project-init.md`
