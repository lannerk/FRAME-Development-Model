# FRAME Model and Effort Assignment Rules for Roles and Tasks (the "assignment rules")

> **Off by default.** The switch is `tier-rule=` in `ai/frame-repo.conf`; when it is missing it means `off`.
> **Off = exactly as if these rules did not exist**: every seat dispatches subagents with its tool's own defaults, and any labels in a task are information only. **On** = subagents are dispatched at the tier their label names.
> 🔴 **"How one session splits work across several subagents" is not governed here** — those five practices are always on, in `ai/rules/workflow.md` §7c.
> The Requester ruled on these rules on 2026-10-10 (in his words: when assigning tasks and defining roles and subagents, "don't write specific models; do it like coding against an interface, and each IDE just implements it according to its own file").

## 1. What is governed, what is not

| | Governed | Not governed |
|---|---|---|
| Sessions | **Subagents**: which tier a dispatch uses | **The main session**: its model and level are chosen by the person who opens it; FRAME cannot set them |
| Files | These rules; the four tier subagent files; one implementation file per tool in `ai/ide/`; the switch and tool lines in `ai/frame-repo.conf` | Each tool's user-level directory (each person's own) |

## 2. The interface: four tiers

| Tier | key / subagent file name | In one line | Who can reach it |
|---|---|---|---|
| Top | `top` / `tier-top` | The strongest, most expensive combination this tool has; better to overpay than be wrong | **Only two ways**: an upgrade request the Requester approved, or a person naming it directly; the record says `top (approved <date>)`. **A label may never say `top` on its own** |
| Strong | `strong` / `tier-strong` | Judging right and wrong, thinking several layers deep, costly if wrong | label `strong` (**the default** — no label means this) |
| Normal | `normal` / `tier-normal` | Clear rules, follow them | label `normal` |
| Light | `light` / `tier-light` | Right or wrong is visible at a glance | label `light` |

1. **Files carry keys only**: `strong` `normal` `light` `top` `complex`, the same in every language (switching languages changes nothing). **Rules, handbooks and tasks never name a model or a level** — those appear only in `ai/ide/<tool>.md`.
2. Each tool has four subagent files with fixed names `tier-top` `tier-strong` `tier-normal` `tier-light`; the main session calls them by name: "use `tier-strong` for this part". **A tool that cannot hold subagent files** (`agents-dir: none` in its header, e.g. Claude app sessions) names the model from section 5 of its file at dispatch; the tier key is still what the task and the record carry.
3. The four files **carry no project knowledge**: the body says only "you are an execution subagent; do what the main session gives you"; the work itself is in the dispatch. So they travel with FRAME and never change per project.
4. A tool that cannot offer four tiers says in its implementation file how they merge (e.g. "top = strong"); the interface and the labels do not change.
5. 🔴 **Upgrade only, never downgrade**: if the one doing the work finds it harder than labelled, it asks the Requester through a **pop-up multiple choice** to go up one tier (why, roughly how much more it costs); only on his yes does it switch, and it says so in one line in the task or record. Going down is not allowed. **The same holds when the named model cannot be dispatched**: that part stops and asks the Requester with a multiple choice (one tier down / wait / one tier up); never step down on your own.

## 3. Labels: three difficulty tiers + complexity

| Label | Tier | What work |
|---|---|---|
| `strong` | Strong | Judging right and wrong, thinking several layers deep, costly if wrong: the core of a shared layer, security checks, keyboard and screen-reader models, state machines, wording of rules, technical approaches, giving a verdict on a review, locating a bug whose cause is unknown |
| `normal` | Normal | Many rules but each one clear: building one part to spec, checking item by item, writing test cases, fixing a bug already located, writing docs and surveys |
| `light` | Light | Right or wrong is visible at a glance: running checks and scripts, retests, counting, matching names, bulk renames, tidying records and archiving |

- 🔴 **Three kinds are always `strong`, whoever labels them**: (1) security (places where outside data becomes a URL, HTML, CSS or a regex); (2) accessibility (keyboard, focus, screen readers); (3) changing anything already finalized (specs, rules, what is already implemented).
- 🔴 **Anything unlabelled is `strong`** (Requester, 2026-10-10: work nobody has judged is better overpaid than wrong). Parts meant to be cheaper are labelled `normal` or `light` by whoever labels them — that is labelling, not "going down".
- **`complex`** (complexity, judged separately from difficulty): more to read than one subagent can hold in one go, more than a dozen or so files to change, the parts must agree on names or interfaces, or the result has to be merged with others' — **any one of these adds it**; once added, split the work per `ai/rules/workflow.md` §7c. **Difficulty decides the tier; complexity decides whether to split** — what one overloaded subagent misses, no stronger tier will rescue.
- **Split by material, not by tier**: several adjacent small parts that read the same material go to one subagent even if their difficulty differs, labelled by the hardest of them; only work whose material genuinely separates gets separate tiers. Why: every subagent starts fresh and reads its material from zero, prompt caches are kept per model, and a subagent cannot change model midway — **splitting one part in two just to change tier means reading the material twice** (Requester, 2026-10-10).

**Defaults by situation** (a reference when labelling; adjust to the case): design, technical approaches, shared layers and generators, locating a bug of unknown cause, review verdicts → `strong`; building one part to spec, writing tests, fixing a located bug, writing docs, item-by-item checks → `normal`; simple display parts, running checks and scripts, retests, translation and bulk renames, records and archiving → `light`. A family, a batch or a shared layer is almost always `complex`.

## 4. Who labels, and where

| Seat | How it is decided | Written where |
|---|---|---|
| **Developer** | the **Reviewer** splits the work into parts when it opens the task / bug and labels each; the Developer's main session dispatches by label; unlabelled = `strong` | the `subagents:` block of the task / bug file |
| **Reviewer** (reviewing others' work) | fixed: review verdicts, reviewing large code → `strong`; checking a family item by item, spot checks, writing tests → `normal`; running checks and scripts, matching names → `light` | nothing to write |
| **Reviewer** (work it gives itself) | **labels it itself** (writing specs, rulings, samples all count), the same way it labels the Developer's work | its own task / progress file |
| **Supervisor** | fixed: checking large pieces, re-running key measurements → `strong`; checking drafts in groups → `normal`; running scripts, counting → `light` | nothing to write |
| **Maintainer** | fixed: changing rules, writing norms → `normal` (the main session owns the wording); running guards, tidying records, checking references → `light` | nothing to write |
| **Researcher** | labels each step itself per section 3 | the research record |

Format (the same for tasks, bugs, research records and the Reviewer's own tasks):

```
subagents:
- <what this part does, in the project's language>: strong
- <a family of display parts>: normal, complex
- <the part whose upgrade was approved>: top (approved 2026-10-10)
```

The block name `subagents:`, the keys and the comma are fixed; the phrase before the colon is in the project's language. The guard accepts only these keys.

## 5. The switch and the tool: two lines, in `ai/frame-repo.conf`

```
ide=claude-code        # tool name = the implementation file's name in ai/ide/; undecided if not chosen yet; a seat using another tool adds ide.<seat>=<tool>
tier-rule=off          # on / off; missing means off
```

They live in the Maintainer's own file (one per repo, never overwritten by sync), **not in `ai/state/now.md`**: that file belongs to the Reviewer and is the most-edited file in the repo, and editing it on every toggle would sweep in another seat's uncommitted changes. The 🔔 line at the top of `now.md` gets one sentence on the current state whenever the switch changes, so every seat still sees it at the start.

| Say to the Maintainer | What it does |
|---|---|
| `tier assignment on` | `tier-rule=on`; generate the current tool's four tier files if missing; **if that implementation file says `verified: no`, test it first** (section 6); one sentence in the 🔔 line; one maintenance-log entry |
| `tier assignment off` | `tier-rule=off`; the subagent files stay; one sentence in the 🔔 line |
| `tier assignment status` | One-line answer: the switch, the tool, whether the four files exist, how long since the implementation file was checked, whether it has been tested |
| `ide <tool> [seat]` | Change `ide=` (`ide.<seat>=` for one seat only); generate that tool's four tier files from `ai/ide/<tool>.md`; the old tool's files stay (each tool reads only its own directory); one maintenance-log entry |

**The switch counts as it stood at the moment of dispatch; nothing is retroactive**: labelled while off and later switched on → dispatch by label; labelled while on and later switched off → labels stay, not enforced; subagents already dispatched are left alone; an approved upgrade stays on record and applies again when the switch comes back on. Why not retroactive: someone would have to go through every task deciding "was this part labelled while on or off", which nobody will do; judged at that moment, every seat can tell at a glance.

## 6. One implementation file per tool: `ai/ide/<tool>.md`

It states which model and level each tier maps to in that tool, where the subagent files live and how to write them, what cannot be done, and how to update it; the format and the update routine are in `ai/ide/README.md`.

- **Written once, in English**, shared by projects in every language — the content is paths, fields, model IDs and links to official docs that are in English anyway; two versions would only drift apart.
- `verified: no` in the header means it was written from the official docs and has not been tested in a project yet. 🔴 **Before switching on, the current tool's file must be tested**: in the project, really dispatch `tier-light` once and `tier-strong` once and see whether the model and level that actually ran are right; if so, set `verified: yes` with the date.
- Every time it runs "sync FRAME", the Maintainer also runs `bash ops/scripts/ide-refresh.sh --all` to see whether any tool's version changed and how long since each was checked.

## 7. The guard `ops/verify/check-ide.sh`

- Always: `tier-rule=` is `on` or `off` only; a tool named in `ide=` has its implementation file; no model names in the rules, the handbooks or `CLAUDE.md` (level names are ordinary English words and are not checked in prose).
- Only when `tier-rule=on`: the current tool's implementation file says `verified: yes`; its four tier files exist; `subagents:` blocks in tasks, bugs and research records use only the keys of section 4.
- A reminder, never red: an implementation file whose `checked:` is more than 90 days old.
