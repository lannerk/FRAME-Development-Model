# The command word "sync FRAME" — the Maintainer follows this file

> **Who reads it**: the Maintainer, the moment the command word "sync FRAME" arrives.
> The mechanism and its criteria are in the header of `ops/frame/frame-sync.sh`; the classes table is `ops/frame/classes.txt`; this repo's profile is `ai/frame-repo.conf`.

## 1. What must hold

**Any FRAME project can be brought into line with the source repository, and neither side loses anything.**
When this project has not changed FRAME, the very same rules produce **a one-way pull from the source** — "one-way" is not a mode, it is what two-way naturally degenerates into.

| | Who it is for | Where it comes from |
|---|---|---|
| **fingerprint** | 🔴 **For the machine**: are the two sides the same FRAME | the aggregate hash of every `follow` file, **computed automatically, never edited by hand** |
| **version** | For people: which version of FRAME this is | 🔴 **bumped by the Maintainer**: structure/roles = major · rule semantics = minor · wording = patch |

## 2. Ten steps (this is what the command word does)

1. Is this project's FRAME clean? Dirty → **refuse**, commit first (🔴 **only committed FRAME counts**).
2. `bash ops/frame/frame-sync.sh --status`: compute this project's fingerprint, read its version.
3. Find the source through `home=` in `ai/frame-repo.conf`; compute its fingerprint and version.
4. **Same fingerprint → answer "already current", touch not one file, done.**
5. `--sync`: the three-way merge produces three lists — **pull in / push out / 🔴 needs a human**.
6. Anything needing a human → **report, write nothing**, hand over the `--diff` command, stop (say the command word again once it is handled).
7. Otherwise → show the report to the Requester → he confirms → `--sync --apply` writes both directions.
8. Recompute both fingerprints (they should match) → **the Maintainer bumps the version** → write `ai/FRAME-VERSION` on both sides.
9. Re-record the baseline (`--apply` does it) and add one line to `ai/rules/maintenance-log.md` on each side.
10. 🔴 Commit the source side and **push it to GitHub** (it is the open-source repository).

## 3. 🔴 The first sync: with no baseline, everything needs a human

A three-way merge needs a baseline to tell **who changed it**, and **the first run has none** — this is **inherent, not an implementation defect**. Two ways through:

- `--diff` each file and decide the direction yourself;
- or, if one side is simply correct, `--adopt` the current state as the baseline. 🔴 **Adopting says the current state is right, so look before you adopt.**

**Write down which of the two you took.**

## 4. Do not "just tidy up" any of these

| Do not | Why |
|---|---|
| Flip the default to `follow` | One unclassified file then **silently loses content**; with `seed` as the default, the same slip only creates a file |
| Let `seed` files take part in two-way overwriting | `CLAUDE.md`, the `index.md` files, `memory.md`, `inbox.md` are filled in by the project — **pushing them back carries project content into FRAME** |
| Delete target files automatically | Deletion is irreversible. 🔴 **If one side deleted it, only report it** — treating a deletion as a new file pushes it back and **nobody can ever delete it** (measured) |
| Use mtime instead of a content fingerprint | `check-template-sync` v1 fell exactly there (a fresh clone reported 11 false reds with nothing changed) |
| Hand-edit the open-source repo's root files | They are **the template plus declared patches** (`map=` / `patch=` in its conf); hand-edit them and the next sync reports "the target changed it" |
