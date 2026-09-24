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

## 5. Open-source users: pull from the source only (`role=consumer` + `push=no`)

> Who reads this: **anyone who took this FRAME from GitHub to run their own project**. You have no
> commit rights on the source repository, so syncing has exactly one direction: **source → your
> project**. This is not a second mechanism, it is the same one plus one line, `push=no`.

**Setting it up (once, three steps)**

1) Clone the source repository **next to your project**, in the same parent directory:

```
cd <the directory above your project>
git clone https://github.com/<the source>/FRAME-Development-Model.git
# result:  parent/your-project/        parent/FRAME-Development-Model/
```

2) Fill in `ai/frame-repo.conf` inside your project — three lines are enough:

```
role=consumer
home=../FRAME-Development-Model
push=no
```

- `home=` may be **relative to your project's root** (so it survives another machine or another
  drive); an absolute path works too.
- 🔴 `push=no` is the point of this section. Without it, a sync **writes your local FRAME changes
  into the source repository** — you cannot push them anyway, so all it does is leave the source
  repo's working tree dirty while you believe the sync succeeded.
- 🔴 **If your project started from the English template, prefix every command with
  `FRAME_TEMPLATE=ai/template-en`**: it decides which of the source's two templates you are
  compared against. Without it you are compared to the Chinese one (measured: 42 false conflicts).

3) Record the first baseline: `bash ops/frame/frame-sync.sh --adopt-mine`

🔴 **`--adopt-mine`, not `--adopt`**: whose content the baseline records decides who every later
difference is attributed to (§3). Recording **your side as it is now** ⇒ everything the source does
later counts as "the source changed it" ⇒ the next round **pulls it in**. Record the source's side
and you are told "you changed 21 files" — when in truth you are 21 files behind, the exact
opposite direction.
🔴 Before you adopt, `--diff` through the files reported as "no baseline": **any file you changed
yourself gets overwritten by the source's copy on the round after adopt-mine.** Move those out
first, the way the rule below says.

**One source repository, several projects**

**One clone of the source is enough.** For each FRAME-based project you have, fill in that project's own
`ai/frame-repo.conf` (all pointing at that one clone) and record a baseline there, then **sync each
project separately**. 🔴 The relative form `home=../FRAME-Development-Model` assumes the source sits
**next to** the project; when it does not, write an absolute path (`home=D:\code\FRAME-Development-Model`).

**🔴 Why the source maintainer has `push=yes` and you have `push=no`, with no switch anywhere**

`ai/frame-repo.conf` is **one per repository** and sits on the **skip** list in `ops/frame/classes.txt` --
**a sync never touches it**. The maintainer's `yes` never reaches you, your `no` never travels back, and
the sample shipped inside the template already says `role=consumer` plus `push=no`.
With no such line, **the role decides**: `consumer` defaults to `no`, `home`/`host` to `yes` --
**a default must make the side that forgets it safe**. A project whose owner maintains the source writes
`push=yes` explicitly (an explicit value always wins over the default).

**Every time you catch up afterwards (four commands)**

```
cd ../FRAME-Development-Model && git pull && cd -   # 🔴 pull runs over there: it is a separate repo
bash ops/frame/frame-sync.sh --sync                 # reports, writes nothing -- read it first
bash ops/frame/frame-sync.sh --sync --apply         # write only once you understand it
bash ops/verify/check-all.sh                        # the rules changed, so the guards changed too
```

Three closing acts: `--stamp <the source's version>` (with `push=no` it writes only your copy) · one line in `ai/rules/maintenance-log.md` ·
tell your AI "reload the rules".

**🔴 Put your own additions in new files; do not edit the ones FRAME ships**

Upstream does not have your new file, so the mechanism recognizes it as **this project's own**,
counts it once in the report and **never touches it** — adding an `ai/rules/ours-xxx.md` costs you
nothing every round, editing `ai/rules/workflow.md` costs you something every round.
If you do edit a file FRAME ships, every round shows one 🔶 "changed locally, not pushed upstream",
with three ways out: **keep the fork** (the baseline records **upstream's** copy, so it is never silently overwritten; once upstream changes that same file it becomes a 🔴 needs-a-human conflict) ·
**drop your version** (delete that file and the next round pulls it back) · **open an issue / PR on the source repo** (this mechanism will not push for you).

**How to tell whether you are current**

| Where to look | How to read it |
|---|---|
| the **fingerprints** in the first two lines of `--sync` | 🔴 **Not a consumer's test**: fingerprints are comparable **only within a role** (the `follow@home` files are not `follow` for you at all), so yours and the source's **differ by construction**. Your test is the last line of the report, "✅ in line with upstream" |
| `source_fingerprint` in `ai/FRAME-VERSION` | It holds "**the source's own** fingerprint at the last sync". Equal to `fingerprint` in the source's `ai/FRAME-VERSION` = you are current. `version` is the number for people; copy it over with `--stamp` |
