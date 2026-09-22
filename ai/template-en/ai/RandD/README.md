# `ai/RandD/` — the workspace of the R&D line

> **Whether to open this line is the Requester's call**; leave the directory empty if it is not open — it disturbs nothing in FRAME.
> The seat's handbook is `ai/roles/researcher.md`; the directory's remit is registered in `ai/rules/layout.md` §2.

## What this line is

**The R&D line runs alongside development; it is not a phase before it.** Once the product is in development there are still new ideas
to verify, new technologies to assess, a next-generation design to settle — all of that runs on this line **without interrupting the development line**.

Three people: the **Requester** gives direction and settles things · the **Researcher** explores and converges · the **Supervisor** verifies, advises and migrates.

🔴 **The Researcher has a seat but not one of the powers.** Until its output has been verified it carries the weight of "I reckon" —
exactly where the existing order of authority puts it: the Requester settles it > a fact the Reviewer verified > the Supervisor's opinion > anyone's "I reckon".
**The four-power structure does not change by a word because of it.**

## Directory rules

```
ai/RandD/
├── README.md                this file
├── index.md                 all topics at a glance (number · topic · started · status · destination)
├── memory.md                🔴 the Researcher's own memory (line-level, cross-topic; same format as `ai/memory.md`, ≤80 lines)
└── NN-topic/                one directory per topic, numbers only go up, kept in place after graduation
    ├── README.md            topic card: what it is for · criteria · status (≤50 lines)
    ├── 00-status.md         🔴 live: current conclusions + what is next (≤200 lines, read every round)
    ├── 01-open-questions.md 🔴 live: what is not settled yet (≤100 lines)
    ├── 02-ideas.md          🔶 half-live: his ideas verbatim, **appended the same round**, required reading at convergence
    ├── decisions.md         RD-#### candidate decisions (they become real ADs at graduation)
    ├── tasks/               R-#### research tasks, one file each + index.md
    ├── notes/               N-#### research notes: **findings** (what the world looks like)
    ├── drafts/              drafts: **claims** (how we think it should be done), not settled yet
    ├── log/                 🔴 dead: the full conversation record (both sides verbatim), by date
    ├── lab/                 🔴 dead: experiment code, **three tiers** (probe / prototype / reference implementation)
    ├── runs/                🔴 dead: data and results from runs (large artifacts are not committed; record how to fetch them)
    └── graduation/          the graduation request · criteria self-check · migration list
```

🔴 **File names stay language-neutral while the content follows your project's language** — the two templates (`ai/template/` and
`ai/template-en/`) must have identical paths, so names do not follow the language; the gate matches those three live files on the
**`00-` `01-` `02-` prefix**, so **translating them does not break it**.

🔴 **The three dead ones are not read day to day**, only their `INDEX.md`; the bodies are opened at convergence and review.
**The context cost is controlled by structure, not by self-discipline and not by deleting content** — delete it and graduation cannot be rebuilt.

🔴 **`ai/RandD/` = everything not yet settled.** Once something is settled the **Supervisor** migrates it out (the plan into `ai/specs/`,
candidate decisions into real `AD####`s, the product definition into `product/`), and **no second copy stays here** — one thing has one home, or the two copies drift apart forever.

### 🔴 Three records, and their jobs never mix

| File | What it holds | Who · when |
|---|---|---|
| `log/` | **the full conversation**: what he said + what the Researcher answered, verbatim, in order | Researcher, **appended the same round** |
| `02-ideas.md` | **only his ideas, in his words**, grouped by theme, with handling and status | Researcher, **appended the same round** |
| `00-status.md` | **current conclusions**: what is settled, what is next | Researcher, updated every round |

In one line: **`log/` is what happened · the ideas book is what he wants · the status file is what we have settled.**

### 🔴 Why there is no `src/`

① The repo root already has a `src/`; a second one confuses `grep`, the IDE and the guard scripts;
② **calling it `src/` plants the suggestion** — "this is source, it runs, move it over" — which is exactly the accident this line exists to prevent;
③ code written while exploring is held to a different standard anyway (no tests, hardcoded paths, no error handling), **so it should not be treated as source**.

Code goes under `lab/<number>-<name>/`, and the README's first line states its tier: **probe / prototype / reference implementation**.
🔴 **There is no "ready to use" tier.** The route is: graduate → the plan enters `ai/specs/` → a task is opened → the Developer rewrites it → the Reviewer reviews it.

## Numbering

`R-####` research tasks · `RD-####` candidate decisions · `N-####` research notes.
🔴 **Never mixed into the development line's `T-####` / `B-####` / `AD####`**: that side has a state machine and gates a research task cannot pass
(no acceptance criteria, direction changes halfway); and putting a candidate decision into `ai/decisions/` **gives unverified material real force**.

## 🔴 The nine graduation criteria (all green before you hand it over)

| # | Criterion | What counts as passing |
|---|---|---|
| 1 | One line each for **what it does · who it is for · what it does not do** | all three can be written, and "what it does not do" is not empty |
| 2 | **The product name is settled** (or it explicitly keeps the host project's) | the name was checked: package registries + system commands + companies in the same field |
| 3 | 🔴 **Every irreversible decision is listed** | each says "change this and what has to be redone" |
| 4 | 🔴 **Every technology choice has a provenance** | one of three: ① verified (give the experiment number) ② a mature precedent (give the source) ③ **openly a bet** + the way out. **There is no fourth option called "should be fine"** |
| 5 | **A risk list** | each risk has a **trigger signal** and a response |
| 6 | **Milestones as far as M0** | what the first acceptable deliverable is, and how it is verified |
| 7 | **Every open item has an owner** | who settles it · by when · what it blocks if it stays open |
| 8 | **Experiments reproduce + each is tiered** | following the README in `lab/` produces the same result |
| 9 | **The Supervisor has verified it + the Requester has settled it** | the last link in the order of authority |

🔴 **Not passing sends you back to exploring; no graduating first and filling the gaps later** — debt taken on during R&D
surfaces mid-development as "nobody ever verified this", and by then the fix costs ten times as much.

## 🔴 The north star: at graduation the whole process can be reconstructed

Every number, every index, the **three axes cross-referencing each other** (time `log/INDEX.md` · question `tasks/index.md` · claim `decisions.md`)
and every same-round append exist for this one thing. **The test: from any point you reach the other two axes within three hops**, and
**can a brand-new session, with nothing but these files, write the graduation output?**

The gate: `bash ops/verify/check-randd.sh` (skeleton complete · every topic listed in the index · live files within their caps · nine green criteria before anything may be marked graduated).
