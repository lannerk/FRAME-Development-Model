# The AI Four-Way Separation of Powers Development Model

### FRAME Development Model

**F**our-**R**ole · **A**udited · **M**aintained · **E**vidence-based

> **One line**: split AI collaboration into **four seats that are independent of each other and check each other** — execution, review, oversight, maintenance —
> then push the collaboration state **entirely out into files**. After that, sessions can be swapped at any time, work never breaks, and nobody gets to be both player and referee.

**Why it is called FRAME**: a frame needs **four sides** to hold its shape; take one away and it falls apart —
and the fourth side (the Maintainer seat) is the one that keeps the other three **square**: rules go stale, get bypassed, and split into two versions, the written one and the practiced one.
With nobody tending them full time, the first three seats will sooner or later each go their own way.
Each of the four words maps to one load-bearing principle: **Four-Role** four-way separation of powers · **Audited** independent review ·
**Maintained** somebody tends the rules · **Evidence-based** every conclusion carries evidence.

---

## 1. What the four powers are

| Seat | Power | What it does | What checks it |
|---|---|---|---|
| **Developer seat** | **Execution authority** | Get the feature built, reliably | The Reviewer can reject it; but it can push back with evidence |
| **Reviewer seat** | **Review authority** | Sets the standard, rules pass/fail, schedules the work, takes requests from the Requester; **also the professional test seat** | The Requester can overrule it; the Developer can overturn it with evidence |
| **Supervisor seat** | **Oversight authority** | Audits the whole project independently, answers directly to the Requester | Its findings must be verified by the Reviewer before they enter the queue |
| **Maintainer seat** | **Rule-making authority** | Maintains the method itself: role handbooks, rules, templates, guards | Moves only once the Requester confirms; **takes no part in development, does not touch requirements** |
| The Requester | **Final-call authority** | Sets direction, calls the trade-offs | — it is where the authority comes from |

**Order of precedence**:

```
the Requester's call  >  facts the Reviewer has verified  >  the Supervisor's opinion  >  anybody's "I think"
how the rules themselves get set   →  the Maintainer (after the Requester confirms)
```

**Separating powers is not dividing labor.** Dividing labor only slices the work up; separating powers **makes the one who judges a different party from the one being judged**.
The real value of this method is in that second half.

**The fourth seat solves a different problem**: the first three seats all **use** the rules; nobody **tends** them.
Once nobody tends the rules, you get "the doc says this, the practice does that" — and that drift **has no symptoms**,
until the day somebody follows the doc step by step and finds out it went wrong long ago.

---

## 2. The problem it is meant to solve

You talk with an AI session for a while and get a fair amount built. Then:

- The session fills up, you open a new one, **it knows nothing**. You restate the background and it misses one of the three things.
- You said "don't do this" last week; two weeks later it does it again — **that sentence only ever existed in a conversation that has scrolled away**.
- It finishes the code and tells you "tests pass, no problems". **It is both the author and the judge.**
- You send three bugs in a row, it replies with a summary and has handled two. **The third evaporated and nobody knows.**
- You ask "what is left", and it has to read the whole project again to answer — and answers incompletely.

None of these are model capability problems. They are **collaboration structure** problems.
One person (or one session) being author, reviewer, recorder and rule-maker at the same time never worked in the first place — **human engineering stopped doing it long ago**.

The four-way separation of powers does exactly one thing: **it moves "who knows what" out of the conversation and into files.**

---

## 3. How the four seats work together

| Seat | Duty in one line | What it looks at | Where its output lands |
|---|---|---|---|
| **Developer seat** | Build the feature reliably (not just "build it") | Its own task + that task's spec | Source code · the "Developer report" in the task file |
| **Reviewer seat** | Senior technical expert **doubling as professional tester and designer**: reviews code, reviews specs, **tests features and UI**, **sets architecture/database/technology choices**, takes requests, schedules work | Tasks awaiting review + current state | The "Review verdict" and "Test verdict" in the task file · the decision ledger · technical specs · designs and plans |
| **Supervisor seat** | The Requester's all-round technical advisor, talks separately, does not tie up the development main line | The specific question you hand it | Its own output directory (committed as is, nobody changes a word) |
| **Maintainer seat** | Maintains the method itself: the rules, the role handbooks, the templates, the guards. **Takes no part in development, does not touch requirements** | The maintenance log + the four rule files + the four role handbooks | The rules and handbooks themselves · the maintenance log · the two generic templates |

### Five rules that make it actually run

**1. You only talk to the Reviewer seat.**
Bugs, things to build, questions, ad-hoc decisions — all of it goes to it. It is responsible for translating them into tasks, specs and decisions.
You do not have to say the same thing to three sessions, and you do not have to remember who you told what.

**2. The Developer seat and the Reviewer seat write the same file.**
This is the load-bearing wall of the whole method. One task, one file: the Reviewer writes the top half — "what to build / how to build it (a suggestion, open to rebuttal) / what counts as done" —
the Developer writes the bottom half — "what was done / evidence / measured results / self-check output / where it differs from the suggestion" — and then the Reviewer writes the "Review verdict".

So: **all the context for one piece of work sits in one file**. Slipping a new task in between does not disturb the old ones;
if either side's session is gone, a new session opens that file and picks up — **it does not need to know what was said before**.

**3. The Maintainer seat handles only the rules, never the work.**
It maintains the role handbooks, the rules, the templates and the guard scripts; it **takes no part in development and does not discuss requirements**.
What you say to it is **not a requirement** — it is "how this method should change". Once confirmed it goes into its **maintenance log** (a separate line from the inbox).
When a rule changes, it is responsible for changing the three seats' handbooks to match, and for **opening a new session to check whether they really follow the new rule**.

**Changing the rules = changing two places**: change it in this project, and the shared template (`ai/template/`) **follows in the same round**; the guard script compares mtime and goes red if it lags.
There is only one test for what goes into the template: **would this still hold in a different project?** — what holds (ways of working, division of labor, directory responsibilities, general pitfalls) goes in;
what does not (what the product is, machines and paths, numbering, the details of one incident) stays out. When syncing, **keep the reasoning, swap the examples**.

**4. The Reviewer seat is also the test seat, and testing and review are two different command words.**
`review` = check whether what it said is true (read the code, check the evidence, run the guards); `review and test` = on top of that, test everything that can be tested:
functionality, UI acceptance, interfaces, **end-to-end operation**, performance, case coverage, regression, and a full test pass where needed.
**What to test is universal; how to test is each project's own business** — some click in a browser, some need a remote session on a test machine,
some need a debugger attached to an engine. So before testing, the Reviewer seat works out this project's testing methods and writes them down as a maintainable document.
There is a layer on the Developer side too: **self-test before handing it in** (walk the acceptance criteria one by one, compare the UI against the finalized prototype one to one); no self-test pass, no submission for review.
**The two layers are worth different things** — a self-test is "I looked at what I made"; the Reviewer's test is "**someone who never wrote this code comes looking for faults**".

**5. The Supervisor seat's findings do not go straight into the development queue.**
Its output goes to you first, you pass it to the Reviewer seat, and the Reviewer **verifies it item by item** (reads the source, runs the measurements) before deciding whether it becomes a task.
When the three disagree, **the disagreement goes only into the Reviewer's verification record, never into the task file the Developer gets** —
the Developer does not need to know who was right; it only needs to know what was finally decided.

### How the checks land: evidence > seniority

**Any seat may rebut any other seat, on condition that it brings source line numbers, measured numbers, or official documentation.**
The Developer overturning a Reviewer suggestion is routine, and it is encouraged — as long as it writes the verification out under "where it differs from the suggestion".
A Reviewer that gets overturned owns it in the review record.

**There is no such thing as "I am the Reviewer, so I decide"** — that would turn the four-way separation of powers into a four-level reporting chain.

---

## 4. Five core mechanisms

### 1. The task state machine — you always know "where it is stuck"

```
todo ──claim──▶ in progress ──report──▶ in review ──review──▶ passed ──▶ archived
  ▲                                                             │
  └────────────────────reject (with reason)◀────────────────────┘

blocked: blocked on an external condition (must say exactly what it waits for and who unblocks it when it arrives)
dropped: requirements changed, or superseded by another task (say which one supersedes it)
```

There are only six states, and changing a state means changing two places at once (the task file header + the task index).
**"What is left" is from now on a question a 40-line file answers**, not a full-project scan.

### 2. The inbox — every sentence you said gets a line

Everything you say, the Reviewer seat records into the inbox **in the same round**: one sentence per line, **verbatim quote, no paraphrase**, and every line must carry a disposition
(opened as a task / turned into a spec / answered on the spot / recorded as a decision / won't do, with the reason written out). **`pending` must be at zero before the round ends.**

Why verbatim: paraphrase drops the **purpose** and leaves only the surface action — and the purpose is the evidence for judging whether the approach is right.
Why the same round: the moment you say "I will write it down once I have tidied it up" is the moment the loss happens.

**Everything you raise gets an echo back, even if the echo is "won't do".**

### 3. Every conclusion carries evidence

Any factual conclusion written into any document must be able to point at a source: **a source line number / a measured number / official documentation** — one of the three.
Two corollaries:

- **Check the file's mtime before citing line numbers** — reading an old version and drawing the wrong conclusion is the most common way to crash.
- **A negative conclusion has to state which form was tried** — "not supported" and "not supported the way I tried it" are two different claims.

### 4. Guard scripts, and the guards themselves get verified

Rules kept in people's heads are gone in three months. So every rule a machine can check is written as a script and goes into the pre-delivery self-check list.
But the corollary matters more:

> **A newly added guard script or guard test must be run once on the spot against a deliberately broken case, with the output showing "it did go red" pasted in.**

Because **a guard script is code too, it can be wrong too, and when it is wrong there are no symptoms** — the self-check stays green forever, you think you are protected, and you are not.
This is not ceremony. It is the step in this method that is easiest to skip and most expensive to have skipped.

### 5. Four things at the end of every stage

1. Update the paragraphs of the "current state" file that this stage changed
2. Change **the implementation column of every decision** this stage touched (the cost of not doing it: nobody can tell what is left)
3. Push the task state to `in review`, finish all five sections of the report, archive the raw self-check output
4. Write one line of commit message (what this stage changed + which decisions it corresponds to)

**Miss one of the four and whoever picks up the next stage has to dig through the code to rebuild the current state — which costs far more than writing those four.**

---

## 5. Compared with single-session "vibe coding", what is better

Fair is fair first: **for a one-off script, for trying out an idea, for fixing one small bug, a single session is faster — do not use this.**
What follows is about the "this project runs for months" case.

| | Single-session vibe coding | FRAME four-way separation of powers |
|---|---|---|
| **Where the context is** | In the conversation. Swap the session and it is gone | **In files. The session is a replaceable execution unit** |
| **Cost of opening a new session** | Restate the background, and inevitably miss things | Say one word ("you are the developer") and it reads for itself |
| **Who judges right and wrong** | It does. Writes and judges | **The Reviewer seat checks independently**, reads the source, runs the measurements, can reject |
| **Do the rules go stale** | There are no rules, or the rules are in the conversation | **The Maintainer seat tends them full time**, and after a change opens a new session to check whether the three seats really follow |
| **Can what you said get lost** | Yes. You have to remember to chase it yourself | Inbox, one sentence per line, cleared to zero before the round ends |
| **"What is left"** | Make it scan again, and the answer is incomplete | One task index, 40 lines |
| **Are the conclusions trustworthy** | "I think it should be fine" | Must carry a source line number / a measured number / official documentation |
| **What if you are interrupted** | Explain the whole thing from the top | Open that task file and keep writing |
| **Token cost** | Restate the background every time; the longer you talk the more it costs | A fixed opening read of a few hundred lines (measured by `ops/verify/check-budget.sh`), the rest on demand |
| **Coming back three months later** | Basically archaeology | Read "current state" + the task index, in the picture in ten minutes |

### The three that matter most

**One. Independent review authority is not "have the AI check it again".**
Say "check that again" in the same session and what it checks is **its own train of thought** — it will tend to confirm itself.
The Reviewer seat is a different session, **without the assumptions that came with writing the code**; what it gets is the result and the evidence, and the only way it can judge is by verifying.
On this point it is the same principle as human code review: **the value of a review comes from independence, not from diligence.**

**Two. Somebody tends the rules, so they do not quietly go stale.**
Any set of collaboration rules drifts away from actual practice as it is used — the doc says A, everyone does B, and **nothing throws an error**.
The first three seats all use the rules; nobody tends them. The fourth seat does exactly that: changes the rules, syncs the template, **opens a new session to check whether they really follow**.
This seat is the reason this method lasts a year instead of three weeks.

**Three. The files are the truth, so sessions are cheap.**
Once all the state is in files, "the session is full", "the model changed", "I closed that window yesterday" all stop being accidents.
You can open three new sessions at any time, close the old ones, go do something else halfway through and come back — **work never breaks**.
The most expensive thing in vibe coding is "context"; this method moves it out of the session, and it stops being expensive.

### The cost, stated plainly

- **A few blanks to fill up front** (project introduction, current state, machine list, self-check list), about ten minutes.
- **Four things to do at the end of every stage**, not skippable — skip them and you are back to vibe coding, now carrying an extra directory layout on top.
- **On small things it is overhead**. Fixing a typo does not need a task file. The test: **will anyone ask about this two weeks from now?**
  Yes → open a task; no → just do it.

---

## 6. User manual: there are only four things you have to do

### 1. Open a session, say one word

Open a session and send one line to each: `developer` / `reviewer` / `supervisor` / `maintainer`, **with no background attached**.
The `CLAUDE.md` at the root loads automatically and routes it to the matching role handbook; it reads the current state and the task queue itself and starts work.

**If it comes back with "what would you like me to do", something is broken** — that is a design problem, not its problem; go check the identity table in `CLAUDE.md`.

### 2. When something comes up, tell only the Reviewer seat

Bugs, new requirements, questions, ad-hoc decisions — dump all of it on the Reviewer seat. It records them in the inbox, translates them into tasks, sets priorities, and tells you where each one went.
**You do not have to remember whether you have mentioned something** — the inbox will tell you.

It will bring you multiple-choice questions for a final call (two or three options + the cost of each + its recommendation and the reasoning).
**It should not bring you open-ended questions** like "what do you think we should do" — that is its job.

### 3. Put the Developer seat to work

To the Developer seat you only need to say `review done, continue`. It goes to the queue itself and takes the highest-priority item.

### 4. Whether to test is your call, made with a command word

Say `review` to the Reviewer seat and it only reviews: read the report, check the evidence, read the code, run the guards.
Say `review and test` and it also has to **actually run it and actually click it** — functionality, UI acceptance, interfaces, end-to-end operation, performance, regression, plus a full test pass before a release.
**Testing costs far more than review**, which is why these are two command words and not one: for everyday small changes say "review";
when you are delivering, going to the real machine, or showing it to someone else, say "review and test".

### 5. Anything that needs your own hands, it saves up and asks once

Plugging in a cable, pasting a key, restarting, verifying something only a person on site can see — it collects these into one batch,
each line stating **how many minutes it needs from you and what it unblocks**.
Conversely, **what it has the permissions to do itself should not be pushed onto you** ("please run this command for me" is not a solution).

---

## 7. The directory layout explained

```
<project-name>/
├── CLAUDE.md              ← the auto-loaded entry point: identity table, command words, hard laws, layout at a glance
├── README.md              ← project introduction for humans
│
├── ai/                    ── everything the three seats collaborate on
│   ├── index.md           whole-project map (required opening read, ≤80 lines)
│   ├── roles/             three role handbooks: developer / reviewer / supervisor
│   ├── rules/             laws hard laws · conventions engineering conventions · workflow collaboration flow · layout directory rules
│   ├── tasks/             **one task, one file** + index + archive ← the load-bearing wall is here
│   ├── decisions/         decision ledger (split into files by number range, each entry with a topic tag)
│   ├── specs/             technical specs (once settled = required reading before work, updated as implemented)
│   ├── state/             now.md current state (≤200 lines, updated at the end of every stage)
│   └── template/          the generic copy for starting a new project (copy the whole thing out)
│
├── product/               ── product definition
│   ├── vision.md          product vision (the evidence the decision ledger sits under)
│   ├── requirements/      **inbox.md the inbox** · verbatim the verbatim quotes · specs specifications · formal formal requirements
│   └── design/            prototype prototypes · ui baseline assets · reference references
│
├── docs/                  ── engineering docs: architecture · directory notes · feature list · operations · real-machine chain
├── src/                   ── source code (one subdirectory per project)
├── ops/                   ── deployment and operations · **machines.json machine list** · **paths.ps1 path definitions** · verify guards
├── dist/                  ── build output (not committed)
├── claude-outputs/        ── AI scratch area: screenshots · measurements · reports · supervisor output (**committed, it is evidence**)
├── archive/               ── history no longer maintained (in only, never out)
└── tmp/                   ── one-off workspace (not committed, whoever makes it cleans it)
```

### Three principles that run through the whole layout

**1. Sort by "does it have a lifecycle", not by "who wrote it".**
Things with state that get referenced again and again (tasks/decisions/specs/requirements) → their own fixed directories;
one-off things belonging to one role (reports, screenshots, measurements) → the scratch area.

**2. One thing has one home.**
The to-do list is only the task index, the handover is only the current-state file, machine information is only `machines.json`, paths are only `paths.ps1`.
**No second copy allowed** — record the same thing in two places and the states will never agree.

**3. Every file has a "reason to read it" and a line limit.**
Index 80 lines, role handbook 150 lines, task file 150 lines, current state 200 lines.
Over the limit, split it. **The budget is not fastidiousness, it is cost** — docs with no ceiling grow to several MB within a year or two,
and at that point any session that reads two of them is a few hundred thousand tokens.

### Only two directories stay out of the repo

`tmp/` (one-off) and `dist/` (build output). **Everything else is committed.**
If you need a one-off file, make it in `tmp/` — **do not make it somewhere else and then come back to add an ignore rule**; that is the standard path to a repo that grows garbage.

**Do not confuse "one-off" with "produced in passing"**: specs, review records, screenshots, measurement data **look like one-off output but have to be kept**,
they are the evidence for a later re-check; things generated during packaging and release **look important but are useless the moment they are used**, and can be rebuilt at any time.

---

## 8. How to start

1. Copy the whole template out as the root directory of the new project (**project name = root directory name**).
   A Chinese-speaking project uses `ai/template/`, any other language uses **`ai/template-en/`** — same content, paths identical to the character.
2. **Open one session and make the first sentence "initialize project"** (say it in whatever language you use; the meaning is what counts).
   It will recognize itself as the **Maintainer seat** and follow `docs/guide/project-init.md`:
   first a multiple-choice question for your **project name** and **working language**, then it localizes the docs into that language and walks you through the five blanks.
   **An existing project goes the same route** — copy the template over it and it will use `ai/frame-manifest.txt` to sort everything into
   "ours / the old project's / name clashes", produce a migration mapping table for you to confirm, then migrate and archive.
3. Open the sessions and say one word to each (`developer` / `reviewer` / `supervisor` / `maintainer`).

The template ships with guard scripts (broken doc links, hardcoded paths and IPs, gaps in the inbox, broken bug loops, whether the template has kept up), usable out of the box.

---

## 9. Remember it in one line

**Move the collaboration state out of the conversation and into files; keep the one who writes apart from the one who judges; make sure somebody tends the rules; give every sentence a landing place and every conclusion evidence.**

Every other rule is an expansion of that one.

---

<sub>The AI Four-Way Separation of Powers Development Model · FRAME (Four-Role · Audited · Maintained · Evidence-based)</sub>
