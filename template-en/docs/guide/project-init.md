# Project initialization — run by the Maintainer seat

> **Who reads this**: the session woken up by "initialize project" — **that session is the Maintainer seat**.
> **What triggers it**: the first sentence of a new session **meaning "initialize project"** counts — whatever language it is in.
> Don't match literal words, **judge by meaning**:
> `初始化项目` / `Initialize the project` / `プロジェクトを初期化` / `프로젝트 초기화` /
> `Inicializar el proyecto` / `Initialiser le projet` / `Projekt initialisieren` /
> `Инициализировать проект` / `تهيئة المشروع` / `Inisialisasi proyek` …
> If the meaning is right, enter this procedure; **don't ask back "did you mean xx?"**.

**Do it in order, don't skip.** Every step has a wrap-up test.
**The test is "no worse than the step 0 baseline", not "all green"** — only step 5 requires all green.
(An old project arrives with red guards from the start; requiring every middle step to be all green deadlocks on the spot.)

---

## Step 0: look first, don't change a single character

The template is laid down as **a whole-root overwrite**, so the root directory may now hold two sets of things mixed together. **This step only looks, it doesn't touch.**

### 0.1 Read your own handbook first

`CLAUDE.md` sent you here, but **your seat's handbook is `ai/roles/maintainer.md`** — read it first.
The ⛔ in it explains that "changing the rules = changing N places" counts as **only one place in a project copied out of the template**;
skip it and at step 5 you will run into a rule you cannot satisfy.

### 0.2 Record a guard baseline (**skip this and you deadlock later**)

```
bash ops/verify/check-inbox.sh ; bash ops/verify/check-bugs.sh
bash ops/verify/check-paths.sh ; bash ops/verify/check-entrypoints.sh
bash ai/check-links.sh
```

**Write down what these print right now.** An old project **usually arrives with something already red** —
say an old doc hard-codes a test-machine IP, `check-paths.sh` goes red on the spot,
and what fixes it is steps 3 and 4. **So the test for the middle steps is "no worse than the baseline"; only step 5 requires all green.**
Without the baseline, at step 5 you cannot tell whether a red is one you broke or one that was red all along.

### 0.3 Tell new from old

```
bash ops/verify/frame-scan.sh
```

- **Class B = 0, and "in the manifest but not here now" = 0** → **a new project**, do steps 1, 2, 4 and 5.
- Otherwise → **an old project**, do all five steps, **step 3 is the heavy one**.

**Two things the script does not do for you**:

- **`archive/` `dist/` `tmp/` are not scanned** (in a live project they are supposed to hold junk).
  **Look at them by hand at initialization** — the old project may well have put things in directories of the same name, and those are invisible to the script.
- **Class B = 0 does not mean a new project.** You still have to rule out class C name collisions (see 3.1). **Only when both are clean is it new.**

### 0.4 Get the lay of git (**required for an old project, and do it first**)

The overwrite happened before you were woken up, and **the files it buried can only be fished out of git**. First confirm the git you are fishing in is **this project's**:

```
git rev-parse --is-inside-work-tree     # false → the old project was never in git; what got buried is really gone
git rev-parse --show-toplevel           # must equal the project root directory!
```

🔴 **If `--show-toplevel` points one level up, you are inside somebody else's repo.**
Then what `git show HEAD:README.md` fishes out is **another project's file**,
and "restoring" from it means overwriting yours with a stranger's content. **If it doesn't match, stop and ask the Requester first.**

Once that is confirmed, this is the most valuable command in this guide:

```
git status --short          #  the lines starting with M = old files the template buried, and that is the class C list
git ls-tree -r HEAD --name-only   # which files the old project had (note: whatever the old .gitignore hid is not in there)
```

**You don't have to guess class C item by item by eye** — `git status` hands you the answer. Only when the old project was never in git do you have to compare by hand,
and in that case **tell the Requester straight away and honestly: which files may already be buried and unrecoverable**.

## Step 1: ask both things at once (**pop-up multiple choice**, don't drag it out one drop at a time)

**Hand both questions to him together through the session's own choice control** (`ai/rules/workflow.md` §4b),
**don't lay the options out in the prose and wait for him to type**. Each gets options and a recommended value:

**Q1 · What is the project called?**
Default = **the name of the repo root directory** (put it up as the first option). If the Requester wants a different name, use his.

**Q2 · Which language do we communicate in?**
That one answer decides three things at once:

1. **This session talks to the Requester in that language from now on**;
2. **The other seats' sessions use that language too** (write it into the "communication language" line at the top of `CLAUDE.md`);
3. **Document content gets translated into it** (see step 2).

🔴 **If the language he speaks already matches this template, don't put up three options.** Those three collapse into the same answer,
and `ai/rules/workflow.md` §4b says outright that "two options that are the same thing in different words waste one unit of his attention".
In that case **one line of confirmation is enough**: "Docs and conversation both in English, right?"

It is only a real multiple choice when the languages differ: **his language** (first choice) / **leave the docs as they are and only talk in his language** (the cost:
from then on the docs the other seats read and what he says are not the same language, and every quote has to be translated on the spot) / **English**.

> **Q1 naturally has only one real option** (the root directory name) + one free-text entry. The control provides "other" itself,
> **don't force a second and a third** — `workflow.md` §4b's "if there is only one reasonable course, just do it" counts here too.
> One more thing for an old project: **finish 0.4 first**, because the buried `README.md` often carries the product's real name,
> and when that name differs from the root directory name you have to put both in front of him.

> **Get the answers before you touch anything.** These two answers affect every file that follows; changing first and asking later means changing for nothing.

---

## Step 2: localization — **translate content, not paths**

If the target language is English, skip this step. Otherwise:

### What to translate

- The **body** of every `.md` doc: the prose, the text inside tables, comments, the example sentences meant for humans.
- The **human-facing parts** of scripts (`.sh` `.ps1`): comments, the text `echo` prints.

> **"Directory names" and "the filenames of content deliverables" are not the same thing** (`ai/rules/layout.md`):
> **directory names are always English**; but **technical specs, database design and explanatory docs -- content deliverables -- take filenames in the working language**.
> Documents carried in from an old project **keep the names they had** -- **never "normalize" them into English abbreviations on the way past**;
> that swaps a name the Requester knows for a code only you know.

### What you may not translate

| Don't translate | Why |
|---|---|
| **Every directory and file name** | The structure has to work across languages; guard scripts, indexes and reuse across projects all depend on them lining up |
| **ID formats** `T-####` `AD####` | Machines and humans both search by them |
| **Guard output markers**: `BUILD-OK` `TEMPLATE-SYNC-OK` `CHECK-PATHS-OK` `INBOX-OK` and the rest | **Scripts hand off to each other through these strings**; translate one and it breaks |
| Code, variable names, JSON keys, config keys | Same as above |

### The class that bites: **words the machine reads too**

Some words sit in the docs (for humans) **and get grepped by scripts** (for machines) —
the status words (`todo` `in progress` `in review` `passed` `blocked` `dropped`) and the inbox's `pending` are exactly that kind.
**Translating the doc without changing the script = the guard silently stops working**, and **nothing errors out at all**.

**The rule**: for words of this kind, **change the script in the same round you translate them**; the list is in **`ai/glossary.md`**,
which says which script reads which word and what else has to change with it. **Read it before you start translating.**

### Wrap-up test (**no worse than the step 0 baseline**, not all green)

```
bash ops/verify/check-inbox.sh      → INBOX-OK
bash ops/verify/check-bugs.sh       → BUGS-OK
bash ops/verify/check-entrypoints.sh → ENTRYPOINTS-OK
bash ops/verify/check-paths.sh      → CHECK-PATHS-OK
bash ai/check-links.sh              → LINKS-OK
```

**Something that was green and is now red usually means you translated straight through a "word the machine reads too"** — go back over `ai/glossary.md`.
**What was already red** (brought in by the old project) **you leave alone** — that is steps 3 and 4's work.

---

## Step 3 (**old projects only**): work out what is what, then migrate and archive

### 3.1 Sort into three classes first, don't rush to move anything

Compare item by item against `ai/frame-manifest.txt` and put everything in the root into one of three classes:

| Class | What it is | How to handle it |
|---|---|---|
| **A · ours** | In the manifest, and the content is the template's | **Leave it alone** |
| **B · the old project's** | Not in the manifest | Sort and migrate per 3.3 |
| **C · name collisions** | A **file of the same name** is in the manifest but the content is the old project's (**in practice `README.md` is almost the only one that really collides** — why, in the two misunderstandings below) | **The dangerous class.** Find them with `git status` (below), and **recover the originals before anything else** |

**How to find class C: not by eye, with `git status`.** That command from 0.4 hands you the list directly:

```
git status --short        #  the ones starting with M are the old files the template buried — that is class C
git show HEAD:<that file>   # fish the original back out exactly as it was
```

**Don't paste what you fished out straight back over the top** — store it as-is in `archive/legacy-<date>/` first, then decide how to merge
(that one-line intro in the old `README.md` is often exactly the project's one line that step 4 asks for).

> **Two common misunderstandings, cleared up first**:
> **`.gitignore` is not class C** — the template ships `gitignore.template`, which is not called `.gitignore`, so it cannot overwrite it;
> it turns up in class B, and how to handle it is under step 4's "how to merge two `.gitignore`s".
> **Directories like `docs/` and `src/` are not class C either** — the manifest is **file-level**, same-named directories just sit side by side,
> and what really collides is only **same-named files**.
>
> **The old project was never in git** (`git rev-parse --is-inside-work-tree` is false): the originals really are gone.
> **Tell the Requester straight away and honestly which files may already be buried**, don't act like nothing is wrong, and don't make up an "it was probably like this" version yourself.

### 3.2 Produce a mapping table, **move only after it is confirmed**

Produce a **migration mapping table**: **old path → new path**, or "not migrating" + why.
**Put it in `claude-outputs/maintainer/<date>-migration-mapping.md`, not in `tmp/`** —
`tmp/` is not in git and is emptied every stage, and this table is the evidence step 5's maintenance log entry has to point at.

**Walk the Requester through it before you start.** This step cannot be skipped — moving something wrong and moving it back costs ten times moving it right the first time.

### 3.3 Where the common things go (per `ai/rules/layout.md`)

| In the old project | Goes to |
|---|---|
| Source | `src/<project>/` |
| Human-facing docs, deployment notes, troubleshooting | `docs/` |
| Requirements, raw chat logs, acceptance criteria | `product/requirements/` (exact words go in `verbatim/`) |
| Designs, prototypes, icons | `product/design/` |
| Build output, installers, images | `dist/` (**not in git**) |
| Packaging / transfer / one-off scripts and copies | `tmp/` (**not in git**) |
| Old specs, old versions, things you can't explain but don't dare delete | `archive/` |
| To-dos and work items that already exist (**the unfinished ones**) | Turn into `ai/tasks/T-####` per `ai/rules/workflow.md` §3 |
| **The finished ones** among the existing to-dos | **Don't migrate them**, leaving them in the snapshot is enough. Migrating them into the queue only makes the queue dirty the day it opens |
| Decisions, conclusions and conventions that already exist | Turn into entries in `ai/decisions/` |
| **Scripts used to run it** (dev/run/test and the like) | They travel with the source: wherever that language puts scripts inside `src/<project>/`. **Only the deployment and ops ones go in `ops/scripts/`** |

**Three easy ones to step on**:

- **Migrated requirements do not go into the inbox.** The inbox only takes **what the Requester says live**;
  stuffing historical requirements in makes `check-inbox.sh` red the day it opens, and step 5 requires it green.
  Historical requirements go **verbatim into `product/requirements/verbatim/`, and whatever is to be done turns straight into a task or a spec**.
- **Don't migrate one thing as two entries.** A line in the old `TODO.md` and a paragraph in the old requirements doc are often the same thing —
  merge them into one task, and point that task's "evidence" at the verbatim file.
- **`feature/` or `suite/`**: the finalized design of a single feature goes in `feature/<name>/`,
  a whole running-state image (desktop, installer, mobile and the like) goes in `suite/<suite>/`. The explanation is in `product/README.md`.

### 3.4 Four hard rules for the migration

1. **Copy, don't move.** A **whole snapshot** of the old structure goes into `archive/legacy-<date>/` (**`<date>` uses `YYYY-MM-DD`**),
   **with not a character deleted**. That snapshot is what the Requester checks against later.
   > `ai/rules/layout.md` has a line "don't stack copies of old files stage by stage" — **this snapshot is its one exception**,
   > the reason being that the old project may never have been in git at all and git can't get it back. It is the only exception; once the migration is done, no second copy.
2. **Coverage check**: **every single file** in the old tree needs a destination in the mapping table, **unmapped must be 0**.
   "Pretty much all moved" does not count — count it out: the old tree's list comes from `git ls-tree -r HEAD --name-only`
   plus `frame-scan.sh`'s class B, **plus the `archive/` `dist/` `tmp/` you looked at by hand in 0.3**
   (the script doesn't scan those three, and whatever the old project put in directories of the same name is invisible to it).
3. **Content check**: whole directories moved get a **sha256 set comparison**; anything rewritten file by file gets **a stated reason per file for the difference**.
   **No file may end up "with no counterpart and no explanation".**
4. **Commit the whole archive directory to git**, and **then** hand the Requester a list of "what in here can be deleted" to confirm.
   **You do not delete it for him.**

### 3.5 Wrap-up test

- Mapping table unmapped = 0, confirmed by the Requester.
- `archive/legacy-<date>/` is in git.
- The "what can be deleted" list has been handed to the Requester (**deleting or not is his business**).

---

## Step 4: fill in the blanks (about ten minutes)

| # | File | What to fill in |
|---|---|---|
| 1 | `gitignore.template` → **rename it to `.gitignore`** | In the template it is deliberately not called `.gitignore` — otherwise, sitting as a subdirectory inside another repo, it would hide the template's own `tmp/README.md` and `dist/README.md` along with it. **This used to be a footnote; it got skipped too many times, so now it is item 1** |
| 2 | `README.md` | One-line project description + stack + directory table (the table is already written, only change the description). **Old project**: that line is often right there in the old `README.md` you fished back out in 3.1 |
| 3 | The top of `CLAUDE.md` | Swap in the one-line description; **fill in the "communication language" line** (the answer to step 1's Q2); **replace the "core framework/platform" in hard laws 2 and 3 with the one your project actually mandates** (delete both if there is none) |
| 4 | **The same two laws** in `ai/rules/laws.md` | Change them **together with the row above**. `CLAUDE.md` is the summary and `laws.md` is the full text; **changing only the summary leaves the full text out of line with it** |
| 5 | `ai/state/now.md` | The "what the system looks like" and "where it runs" sections + the date and the 🔔 line at the top — this is the first thing a new session reads |
| 6 | `ops/machines.json` | Dev machine / test machine / build machine. **This is the only place an IP may be written**; move the hard-coded IPs out of the old docs to here and change the docs to reference them by `id` |
| 7 | `ai/rules/conventions.md` §5 | **The pre-delivery self-check list**: which commands your project has to run before it counts as "done" |
| 8 | **Rename the placeholder directory** | Rename `product/design/prototype/_PROJECT_/` to the project name; create `src/<project name>/` as needed. **The new name may not contain `<>:"\|?*`** -- Windows cannot create those (`ops/verify/check-filenames.sh` catches it) |
| 9 | **Delete `SYNC.md`** | It is for maintaining the template, not a part of the project |

Everything else (`ai/roles/*`, `ai/rules/{workflow,layout}.md`, each directory's README) **works without being changed**.

> **After item 8, `ai/frame-manifest.txt` no longer matches this repo one to one — that is normal.**
> That manifest is **a snapshot of "what the template looks like"**, used to tell what is what at the moment of initialization,
> **not a checklist for this project afterwards**. Once initialization is done, its job is over.

### Old project: how to merge two `.gitignore`s

The old project brings a `.gitignore` of its own, and the template tells you to create one. **Don't just overwrite**:

1. The old one **goes into the snapshot first** (`archive/legacy-<date>/.gitignore`);
2. Go through the old rules one by one: **drop the ones the template already covers** (example: the old `*.pyc` is swallowed by the template's `*.py[cod]`),
   **and drop the ones that stopped applying because artifacts now go in `dist/`** (example: the old `/build`);
3. **Only what is left gets merged into the new one**, with one line beside it saying where it came from.

**One more thing**: the Reviewer seat's `ai/specs/{testing,architecture,database,tech-stack}.md` are all empty skeletons,
**that seat fills them in, you don't do it for them**.

## Step 5: wrap up

1. **Every guard green**: `check-inbox` · `check-paths` · `check-bugs` · `check-entrypoints` · `ai/check-links.sh`.
   **This is the step that requires all green** (the baseline recorded in step 0 must be fully absorbed by now).
   Anything still red: say which one, why and who fixes it — **you may not wave a red through as a "known issue"**.
2. **`.gitignore` exists** (step 4's item 1 is the easiest to skip, so it is verified once more here):
   `ls -a .gitignore` finds it, and `git check-ignore -q dist tmp` passes.
3. Write into `ai/state/now.md`: **the project is initialized, the project name, the communication language, and (for an old project) the migration summary**,
   and set the date on the top 🔔 line to today.
4. **Entry 1 of the maintenance log** (`ai/rules/maintenance-log.md`): project name, language, what the old-project migration did,
   **with the Requester's verbatim quote attached**, pointing at `claude-outputs/maintainer/<date>-migration-mapping.md`.
   > That log has a line saying "maintenance is not done while `check-template-sync.sh` is red" —
   > **that one only counts for the repo that owns the template**; this project of yours doesn't have that script at all, **skip it**
   > (the ⛔ at the top of `ai/roles/maintainer.md` explains why).
5. **One extra for an old project**: hand the Requester the "what in the archive directory can be deleted" list to confirm. **You do not delete it for him.**
6. Tell the Requester **how to use it from here**: open three sessions and say one line in each — `developer` / `reviewer` / `supervisor`;
   take everything to the Reviewer seat only; to get it tested, say "review and test"; when the rules change, say "reload rules" to the running sessions.

## Appendix: what the four seats do

| Seat | In one line | Where the output lands |
|---|---|---|
| **Developer** | Implement the feature reliably (not just "implement it"); **self-test before handing it to review** | `src/` · the task file's "Developer report" and "Self-test" |
| **Reviewer** | Senior technical expert **and professional tester**: review code and specs, test features and UI, take requirements from the Requester, hand out work | The task file's "Review verdict" and "Test verdict" · `ai/decisions/` · `ai/specs/` |
| **Supervisor** | The Requester's all-round technical advisor, talked to separately, not occupying the development line | `claude-outputs/supervisor/` (committed as-is) |
| **Maintainer** | Maintains the model itself: rules, role manuals, templates (Chinese version + English version), guards | `ai/rules/maintenance-log.md` · `ai/template*/` |

**The key mechanism: the Developer and the Reviewer write into the same task file.** Slotting a new task in between doesn't disturb the old one; if either side drops out,
the other picks it up straight from the file — **no need to stuff context into the conversation, and nothing is lost when the session changes**.

## What this structure solves

It grew out of a real project, and that project stepped on all of these:

| Pit | How this structure blocks it |
|---|---|
| Docs grew to 1.7MB, every session burned hundreds of thousands of tokens just opening | Every file has **a reason to read it and a line cap** (`ai/rules/layout.md` §3); required opening reading is about 260 lines |
| The same thing had a different status in four to-do lists | **The only to-do list is `ai/tasks/index.md`, the only handover is `ai/state/now.md`**; no second one allowed |
| The ledger's "implementation" column was entirely untrustworthy, nobody knew what was left | Every stage's wrap-up **must** update the implementation column of every decision it touched (one of the four wrap-up items) |
| One thing's context was scattered across three huge files | **One task, one file**; review and development write into the same one |
| A directory got renamed and nobody went back to sweep the old paths out of the deploy scripts | Paths are defined once in `ops/paths.ps1` + guarded by `ops/verify/check-paths.sh` |
| Switching to another test machine meant changing a hundred-odd places | Machines are defined only in `ops/machines.json` + the same guard sweeps for hard-coded IPs |
| A guard script was added, but the guard itself was broken and nobody noticed | **A newly added guard must be run once against a deliberately broken case on the spot, with the "it really did go red" output pasted in** |
| "Done" meant the code was written, and the real machine turned out to be full of holes | Development **self-tests** before handing it to review; the Reviewer seat is a **professional tester**, and when the Requester says "review and test" the whole thing gets tested |
| Temporary files piled up until someone had to clear gigabytes of garbage by hand | Only `tmp/` and `dist/` stay out of the repo; in `tmp/` whoever makes it cleans it, deleted at this stage's wrap-up |

**If your project doesn't need one of these, delete it** — but think about that left column before you do. Every one of them was paid for with a real incident.
