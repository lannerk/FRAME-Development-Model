# Template sync checklist

> **When you start a new project from this template, delete `SYNC.md`** — it is for maintaining the template, it is not part of the project.
>
> **Maintaining this template is the Maintainer's job** (`ai/roles/maintainer.md`).
>
> **This template is the generic copy of this project's new structure.** When the new design settles a better convention or an improvement, **sync it here in the same round**.
> Guard: `ops/verify/check-template-sync.sh` (compares **content fingerprints**, and splits class A into "generic-rule" and "project-content" files with different criteria — see "How syncing is judged" at the end).

## What gets into the template: **things unrelated to the project itself, generic and common**

When syncing, ask one question: **on a different project, does this still hold?**

- **Holds → in**: how things are done, role duties and who has the say, directory responsibilities and naming, the state machine, wrap-up criteria, generic pitfalls.
- **Does not hold → out**: what the product is, the stack, machines/IPs/paths/ports, AD numbers, task numbers, specific file names, the details of one particular incident.

A rule often has both in it. **Keep the reasoning, swap the example** —
replace project-specific names with placeholders, boil the incident details down to one generic sentence, leave the reasoning exactly as it is.

> It goes wrong in both directions: project-specific things mixed into the template, and a new project carries history that is not its own from day one;
> generic improvements not synced, and the template quietly goes stale.

## Two classes

### A · Structural files — change a source file and it must be synced (strip the project-specific content)

| This project | Template | What to do when syncing |
|---|---|---|
| `FRAME-Development-Model.md` | `ai/template/FRAME-Development-Model.md` | **as is** (it is generic already) |
| `README.md` | `ai/template/README.md` | replace with the fill-in-the-blanks version |
| `CLAUDE.md` | `ai/template/CLAUDE.md` | swap out the product intro paragraph; put "core framework" in hard laws 2/3 back to a placeholder |
| `ai/index.md` | `ai/template/ai/index.md` | project name to a placeholder; the three "current state" lines to placeholders |
| `ai/roles/developer.md` | `ai/template/ai/roles/developer.md` | point the self-check list at `conventions.md` §5; drop this project's concrete examples |
| `ai/roles/reviewer.md` | `ai/template/ai/roles/reviewer.md` | same as above |
| `ai/roles/supervisor.md` | `ai/template/ai/roles/supervisor.md` | same as above |
| `ai/roles/maintainer.md` | `ai/template/ai/roles/maintainer.md` | **as is** (it is generic already) |
| `ai/rules/maintenance-log.md` | `ai/template/ai/rules/maintenance-log.md` | empty the table, keep only the rules and the status definitions |
| `ai/rules/laws.md` | `ai/template/ai/rules/laws.md` | drop the AD numbers; hard laws 2/3 become a placeholder + "delete these two if there is no core platform" |
| `ai/rules/workflow.md` | `ai/template/ai/rules/workflow.md` | **almost as is** (the state machine, the task template, priorities and the four wrap-up items are all generic) |
| `ai/rules/layout.md` | `ai/template/ai/rules/layout.md` | **almost as is** (directory responsibilities, size budgets, naming and the banned items are all generic) |
| `ai/rules/conventions.md` | `ai/template/ai/rules/conventions.md` | §1 §2 §6 §7 §8 carried over as generic; **§3 §4 §5 replaced with fill-in-the-blanks tables** |
| `ops/verify/check-cachebust.sh` | `ai/template/ops/verify/check-cachebust.sh` | **as-is** (it skips itself when the project has no frontend) |
| `ops/verify/check-randd.sh` | `ai/template/ops/verify/check-randd.sh` | **as-is** (it skips itself when the project has no R&D line; the criteria match on the `00-` `01-` `02-` prefix, **not on the language**) |
| `ai/roles/researcher.md` | `ai/template/ai/roles/researcher.md` | **as-is** (the Researcher's boundary and its four per-round duties are generic) |
| `ai/RandD/` (the whole tree) | `ai/template/ai/RandD/` | **an empty skeleton**: `README.md` (the rules + the nine criteria) · an empty `index.md` · an empty `memory.md` · one `NN-topic/` skeleton (an `INDEX.md` in each of the four archive dirs). 🔴 **Neutral file names, content in the project's language** — the two templates' paths must match character for character |
| `ai/mail/to-researcher/from-supervisor.md` · `ai/mail/to-supervisor/from-researcher.md` | same paths | **empty mailboxes** (the Researcher exchanges letters only with the Supervisor; the gate reds any other pairing) |
| `ops/frame/frame-sync.sh` · `ops/frame/classes.txt` | same paths | **as-is** (the tool behind "sync FRAME" and its classes table; repositories differ only through their own `ai/frame-repo.conf`, **no repo name is hard-coded**) |
| `docs/guide/frame-sync.md` | `ai/template/docs/guide/frame-sync.md` | **as-is** (the ten steps, the five iron rules and the open-source one-way-pull section are all generic) |
| `ai/FRAME-VERSION` | `ai/template/ai/FRAME-VERSION` | **the version travels with FRAME**; `fingerprint` is computed by the script, never filled in by hand |
| `ai/frame-repo.conf` | `ai/template/ai/frame-repo.conf` | **a blank sample**: `role=consumer` plus a `home=<absolute path or ../the-source>` placeholder plus `push=no` (open-source users pull one way), filled in at initialization. 🔴 **Sync never overwrites it** (it is on the skip list) |
| `ai/decisions/index.md` | `ai/template/ai/decisions/index.md` | reset numbering to AD1; drop the section on this project's known numbering problems |
| `ai/tasks/index.md` | `ai/template/ai/tasks/index.md` | empty the table; reset the task number to T-0001 |
| `ai/specs/index.md` | `ai/template/ai/specs/index.md` | empty the table, keep only the file-header rules |
| `ai/specs/testing.md` | `ai/template/ai/specs/testing.md` | **skeleton only**: the four blanks for the eight categories (method/environment/action/evidence) and how to fill them; drop this project's machines, engines, ISOs and the like |
| `ai/state/now.md` | `ai/template/ai/state/now.md` | all of it replaced with blanks |
| `ai/check-links.sh` | `ai/template/ai/check-links.sh` | **as is** |
| `ops/verify/check-paths.sh` | `ai/template/ops/verify/check-paths.sh` | replace the string of old directory names with placeholders |
| `ops/verify/check-inbox.sh` | `ai/template/ops/verify/check-inbox.sh` | **as is** |
| `ops/paths.ps1` | `ai/template/ops/paths.ps1` | project subdirectory name to a placeholder |
| `ops/machines.json` | `ai/template/ops/machines.json` | replace with one example machine |
| `product/requirements/inbox.md` | `ai/template/product/requirements/inbox.md` | empty the table, keep only the rules and the status definitions |
| `claude-outputs/README.md` | `ai/template/claude-outputs/README.md` | in the promote table, replace this project's own rows with placeholders |
| each directory's `README.md` (`docs/ ops/ product/ src/ dist/ tmp/ archive/`) | same name | drop this project's examples |
| `.gitignore` | `ai/template/gitignore.template` | drop this project's own build-output names |

### B · Template-only — not in this project, nothing flows back

| File | What it is |
|---|---|
| `docs/guide/project-init.md` | the ten-minute starter guide for a new project (fill in five blanks → tell the AI its identity → open the first task) |
| `SYNC.md` | this file |

## C · This project only — does not go into the template

One-off migration scripts and notes (`MIGRATION*.md`, `ops/verify/migration-map.py` and the like) — used once, then gone. They do not go into the template.

## D - The English template `ai/template-en/`

**The same thing in English. Different content language, paths identical to the character.**

| | |
|---|---|
| **Who maintains it** | The Maintainer seat. Changing one rule = changing three places: this project + `ai/template/` + `ai/template-en/` (the opening rule in `ai/roles/maintainer.md`) |
| **When it is used** | It is the starting point when the Requester opens a project in English or any other non-Chinese language; during "initialize project" it is the **source text for translation** |
| **Hard constraint** | The two templates' **file lists must be identical**. `diff <(cd ai/template && find . -type f\|sort) <(cd ai/template-en && find . -type f\|sort)` must be empty |
| **Guard** | `ops/verify/check-template-sync.sh` compares content fingerprints both for "project -> Chinese template" and for "Chinese template -> English template", diffs the two file lists, and compares their structure (heading and table-row counts) |

**Three things to watch when translating**:

1. **Translate content, never paths.** Directory names, file names and the names inside angle-bracket placeholders stay English and identical across both.
2. **Words the machine also reads must be changed in the scripts in the same pass**: the states, the inbox's `pending`, the bug states, and section names like `- **Steps**:` `- **Symptom**:` `## Retest` -- `check-inbox.sh` and `check-bugs.sh` grep for them. The list is in `ai/glossary.md`. **Verify both directions after changing them** (create a bad row, watch it go red; delete it, watch it go green).
3. **Guard output markers are never translated**: `INBOX-OK` `BUGS-OK` `CHECK-PATHS-OK` `TEMPLATE-SYNC-OK` `FRAME-SCAN-DONE`. The one exception is the link checker's human line: the Chinese prints its own wording, the English prints `LINKS-OK` -- **the documents that quote it must follow** (`docs/guide/project-init.md`).

## When to sync

**Change any source file in class A, sync it in the same round.** Do not let it pile up — piled up until next time means "the template and the actual practice do not match",
and starting a new project from it then gives you an out-of-date methodology.

## The criterion for syncing

```
bash ops/verify/check-template-sync.sh
```

It compares **content fingerprints** (not mtime — mtime is a textual shadow; one `git clone` changes them all),
and **class A is split in two** (the Supervisor seat proposed this on 2026-09-15; it was adopted after the false alarms actually fired):

| | Which | How it is judged |
|---|---|---|
| **Generic-rule files** | the role handbooks · `ai/rules/` · the guard scripts · `CLAUDE.md` · `README.md` · `FRAME-Development-Model.md` | **the source changed and the template did not move a character = not synced** (content-fingerprint accounting) |
| **Project-content files** | `ai/memory.md` · `ai/state/now.md` · `ai/bugs/index.md` · `ai/tasks/index.md` · `ai/decisions/index.md` · `ai/rules/maintenance-log.md` · `product/requirements/inbox.md` · `ops/machines.json` · **`ai/mail/to-<recipient>/from-<sender>.md` and `ai/mail/archive/*`** | the template copy **is a blank / fill-in form by design, so the two sides should never be the same**. No fingerprint comparison; three things are checked instead: **no internal IP · no filled-in ledger row · placeholders or blank rows still there**; the mailboxes are stricter — **not a single letter is allowed in the template** (that check looks at data rows, not at a `<YYYY-MM>` in the prose) |

**Why the split**: leaving the project-content files in the fingerprint accounting turns every memory entry and every ledger
move in this project red, and the only cure is `--accept` — **a high false-alarm rate plus a one-key mute always degrades into reflexively pressing mute**.

It also compares: **the section-heading and table-row counts of every .md in the two templates** (fingerprints cannot catch "the English one drifted into something else"),
**that the two templates' file lists match character for character**, and whether `ai/frame-manifest.txt` is current.
🔴 **`--accept` is the last action after all three copies are changed, not a button that turns the check green.**
