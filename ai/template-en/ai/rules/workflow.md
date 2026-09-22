# Collaboration flow · how the three roles work together

## 1. One picture

```
Requester ──states need──▶ Reviewer ──writes up──▶ product/requirements/specs/ ──▶ open a task
    │                          ▲                                                      │
    │                          │verify item by item                                   │todo
    └──forwards output──▶ Supervisor output                                           ▼
              claude-outputs/supervisor/                                   Developer builds
                                                                                      │in review
                                          Review verdict ◀────────────────────────────┘
                                   pass → archive/ / reject → back to todo
```

**The task file is the only carrier of truth**: the Developer and the Reviewer **write the same file**. Inserting a new task in the middle doesn't disturb the old ones; if either side drops out, the other picks up straight from the file.

## 2. The task state machine

```
todo ──developer claims──▶ in progress ──reports──▶ in review ──review──▶ passed ──▶ tasks/archive/
  ▲                                                                          │
  └────────────────── reject (state the reason) ◀────────────────────────────┘

blocked: blocked on the Requester / the real machine / another task ("blocked on" must spell out what it waits for and who unlocks it once that arrives)
dropped: the requirement changed or another task superseded it (state which one superseded it)
```

- 🔴 **Open the next ticket the moment one goes to `in review`** — review is **asynchronous**; do not stop for the verdict.
- **There are only these six states**, don't invent more. `pass with follow-up` is a **review verdict, not a state**: the task still goes to `passed`,
  and the follow-up part **must get its own `T-####`**; if you can't open one, it's a `reject`.
- Changing a state **changes two places**: the task file header + `tasks/index.md`.
- `blocked` with no "blocked on" filled in = `todo`. If the wait never ends, move it to `dropped` and say so; don't leave it hanging for show.
- Passed tasks move into `tasks/archive/` in batches **after 3 stages** (flat, keeping their `T-####` names); the index keeps only the unfinished ones. Archiving is not deleting: `grep -rl "T-0012" tasks/archive/` finds it again any time.

## 3. Task file template (copy it, don't drop a single field)

```markdown
---
id: T-0042
title: <one line saying what this task is>
raised by: Reviewer            # Reviewer / Requester / Developer / Supervisor
type: development       # development / advisory (advisory = a consult ticket assigned to the Supervisor seat, see §5b)
assigned to: developer  # developer / supervisor (advisory task)
status: todo            # one of the six states
priority: P1              # P0 right now / P1 this stage / P2 next stage / P3 when free / P4 don't forget
evidence: AD<number>
spec: ai/specs/<name>.md              # the finalized technical spec, required reading before you start
prototype: product/design/prototype/_PROJECT_/feature/<name>/   # the finalized design and icons; write — if there is none
bug: B-####                          # the bug this task fixes; write — if there is none
milestone: M-##                      # which milestone it belongs to; write — if there is none
blocked on: —
opened: 2026-09-16
updated: 2026-09-16
---

## What to do (Reviewer writes)
One or two sentences on the goal and the boundary; no implementation detail.

## How to do it (suggestion · can be pushed back on)
The approach and evidence the Reviewer gives. **The Developer may do it differently**, but must write down why below.

## Acceptance (Reviewer writes, Developer works against it)
- [ ] Checkable and verifiable; every line provable with a command or a screenshot
- [ ] No unverifiable wording like "the feature works"

## Developer report
- **What was done**:
- **Evidence**: source line numbers / official docs / measured numbers (pick one of the three, never empty)
- **Measured**: how it was verified on the real machine and what came out
- **Self-check output**: results of the self-check list (`ai/rules/conventions.md` §5; how many checks is up to your project), pasted as the file name under `claude-outputs/developer/`
- **Where it differs from the suggestion**: what changed, how it was verified, why the suggested way doesn't fit (write "none" if there is none)
- **Bugs fixed**: `B-####` (write `none` if you fixed none). **If this line is filled in, the Reviewer seat must retest this round**
- 🔴 **Why I stopped here** (**the last line of the report; it must be there**): only one of four —
  **① needs the Requester to settle it** · **② needs real hardware/conditions I do not have** · **③ going further would cut someone off the network or lose data** · **④ the design contradicts itself, so doing it would be wrong anyway**.
  If there were still doable tickets in the queue and you stopped, **not being able to name one of those four is itself grounds to send the work back**.
  "This ticket is done" does not count — that is handing one over, not stopping.

## Self-test (Developer writes; required before pushing to `in review`)
- **Build reconciliation**: rebuild from **the whole repo tree** and the artifact's hash must equal the hash of what is running on the test machine; a mismatch means something was never written back — find it now. **Per-file hashes only bite the files someone remembered**; this one bites the whole class of "forgot to write it back". (The build has to be reproducible: strip build paths, timestamps and anything else that would make the two sides differ forever.)
- **Function**: the result of walking "Acceptance" item by item (each one pass / fail)
- **UI one-to-one**: which items were compared against `prototype`, whether the four states plus narrow screen and dark mode were checked, where the screenshots are
- **Surroundings**: who else uses the shared dependencies you touched, and whether you clicked through them
- (A task with no interface writes "no UI in this one"; never leave the whole section empty)

## Review verdict
- **Round N (date)**: pass / pass with follow-up (attach `T-####`) / reject. On a reject, state which item, why, and how to fix it.

## Test verdict (Reviewer writes; present only when the Requester says "review and test")
| Category | Result | Evidence / why it wasn't tested |
|---|---|---|
| Function | | |
| UI acceptance | | |
| Interfaces | | |
| End-to-end operation | | |
| Performance | | |
| Case coverage | | |
| Regression | | |
| Full pass | | |
```

> How the methods are set: see `ai/specs/testing.md` (the Reviewer seat writes and maintains it). **Not one of the eight rows may be empty** —
> if it wasn't tested, say why; **an empty cell means you never thought about it**.

## 3b. How a bug moves

Bugs and tasks are two separate ledgers: **a bug records "what's broken and how to reproduce it", a task records "who fixes it and what it should become".**
A bug lives in `ai/bugs/B-####-<one line>.md`, the work of fixing it in `ai/tasks/T-####`; the two point at each other.

**Four prohibitions**: (1) **the four reproduction pieces** (environment / preconditions / steps / symptom) not filled in completely, it may not go to development;
(2) development **may not mark it `closed` itself**, closing authority is the Reviewer seat's; (3) "Bugs fixed" in the report is not `none`,
**the Reviewer seat must retest this round**, it is not hung on the "review and test" command word; (4) a bug the Requester reports, **the Reviewer seat reproduces once itself first**,
and if it does not reproduce, mark it `to reproduce` and go back for the conditions — **never dump it on development to guess at**.

**The bug file template, the four origins, the state machine, how to write the localization section**: **`ai/bugs/README.md`**.


## 3c. The rules changed mid-flight — what happens to work in progress: **no retroactive effect**

**The criterion is time, not argument**: when the task was pushed to `in review` vs when the rule file changed.
**A rule later than the delivery may not be used to reject it** — development cannot write against a template that did not exist yet.

🔴 **Read the time from git, not from mtime** (changed 2026-09-15; the reason is in `ai/memory.md`, entry 8):

```
git log -1 --format=%cI -- ai/rules/workflow.md     # when this rule file was last committed
git log -1 --format=%cI -- ai/tasks/<task>.md     # when that delivery happened (the commit that pushed it to `in review`)
```

**mtime is a textual shadow**: one `git clone`, a different machine, or a CI run rewrites every file's mtime to the checkout
moment and **"which came first" stops working on the spot** (measured: in a fresh clone all files were milliseconds apart).
Changes not yet committed count as "now".

| Case | What to do |
|---|---|
| Rule **later** than delivery, what is missing is a **field or a section** | **The Reviewer seat fills it in** (it can edit documents anyway) and notes in the task: "the rule landed after the delivery; fields filled in by the Reviewer seat, **not counted in the verdict**" |
| Rule **later** than delivery, and the new rule changes **how it is done** | Review this one **against the old rules**; open a separate task for the new way, with the evidence |
| Rule **earlier** than delivery and development did not follow it | Reject, normally |
| **Exception: the new rule exists to stop an incident already happening** (security, data loss) | **It is retroactive**, and the task says why this one is |

**The next task runs under the new rules in full.** No retroactive effect does not mean no effect.

> **The Maintainer seat's half of this**: after changing a rule, the 🔔 line at the top of `ai/state/now.md` carries **a date**,
> so "which came first" is a matter of record, not of whose memory is better.

## 3d. The task touches **another seat's files** — now what

The ownership table in §7 says **who maintains a file, whose red it is, who commits it** — **not who is allowed to touch it**.
A task the Requester has settled may send one seat into another seat's files; that is what the order of authority means.
So each end does one thing:

| Who | When | What |
|---|---|---|
| **The seat opening the task** | Before opening it | Check it against §7 and **write "which files belong to whom" into the ticket**; name them in "what to do" when it crosses seats |
| **The seat doing the work** | On noticing it crosses | **Do it, don't stop** (stopping to wait for a ruling leaves the hole open one more round), but **mail the owning seat the same round**: which files, why, and which parts went beyond the ticket |
| **The owning seat** | Next mail check | Review it, revert what is wrong, and write the verdict into the archived row (`ai/mail/README.md`) |

🔴 **These three always require a letter** — skip it and the books changed with nobody knowing: ① you touched `ai/template/*` / `ai/template-en/*`;
② you ran `check-template-sync.sh --accept` (it rewrites `ops/verify/.sync-state`, **the sync ledger for every template pair**, which is not yours for the round);
③ you added or rewrote a gate under `ops/verify/*`.

**Measured in the project this template came from**: three of a ticket's four items belonged to the Maintainer seat; the seat doing
the work finished the ticket and mailed a report the same round, and the owning seat reviewed it next round and corrected two things
(only one language of the template had been synced · the script had this project's filename prefix hard-coded).
**Crossing seats is not the mistake; not reporting it is.**

## 4. How the Requester's input comes in

1. Store the exact words **with not a character changed** in `product/requirements/verbatim/<date>-<one line>.md`.
   Why keep it verbatim: paraphrase loses things. We've been burned — "chunked multi-part upload" got paraphrased into "just upload reliably", losing its real purpose (letting the AI upload by itself).
2. The Reviewer writes it up into an acceptable spec → `product/requirements/specs/<feature>.md`.
3. Anything needing a final call becomes a **multiple choice** (two or three options + the cost of each + a recommendation with reasons). **Hand them to him through the pop-up control** (see §4b).
4. Record the final call as an AD, and mark it **"Requester's final call" and not "called on his behalf"** — development sees that line and doesn't have to ask.
5. He interjects mid-round: fold it into the current round and **rewrite the development copy as a complete version** (development only reads the latest one).

## 4b. Dealing with him: **the whole block is in `ai/rules/requester.md`**

Three rules; the detail is in that file:

1. **Need his call, use a pop-up multiple choice** — never list A/B/C in the prose for him to type back; recommended one first and marked (recommended), every option states its cost.
2. **Do not just do as told** — if you can infer something better, put it up for him to confirm (**do the thing he asked first, then say there are a few other possibilities, each with its cost**).
3. **He told the wrong seat**: take it, don't do it, tell him who to go to and what to open with; **if he insists, do it**, but state the cost first and leave a trace.


## 4d. He asks "what is left to do / what bugs are left": **list within the scope he asked about**

This question can come at any time, and **the answer has to be pulled from the ledgers, never from memory** — memory drops things, and the one it drops is the one he cares about.

**Four ledgers, each covering one stage**:

| What he asks | Where to pull it from |
|---|---|
| What is left to do / how far along | `ai/tasks/index.md` (the unclosed ones) |
| What bugs are left | the "open" table in `ai/bugs/index.md` |
| What about that thing I said last time | `product/requirements/inbox.md` (even the `won't do` ones must have a disposition you can report) |
| Why was it settled this way | `ai/decisions/` (look it up in the number-range file, do not read it all) |

**"Within scope" is the crux of this** — he rarely wants everything. First work out which kind of scope he drew, then filter:

| He asks it like this | What you filter on |
|---|---|
| "**what is still urgent**" | priority P0/P1 |
| "**what is left on the VPN side**" | feature / module |
| "**are there any serious bugs**" | severity S1/S2 |
| "**what is stuck**" | status `blocked` + state what it is blocked on and who unblocks it |
| "**the things I said last week**" | time range (the inbox has dates) |
| "**what does development have in hand**" | status `in progress` / `in review` |
| "**what is this release still missing**" | the tasks tied to that version + unclosed bugs — **report both ledgers together** |

**The reporting format (four parts, none of them skipped)**:

1. **Total and scope first**: "you asked about VPN: 6 unclosed items + 2 bugs" — **he needs to know how big it is first**;
2. One line per item: **id + one sentence + status + where it is stuck** (if it is not stuck, say whose hands it is in);
3. **Sort by his scope** (asked about what is urgent, sort by priority; asked about a module, group by module);
4. End with one line of **your judgment**: which to do first and why. What he wants is judgment, not a list.

**Three prohibitions**:

- **Do not leave out `blocked` and `won't do`.** He asks "what is left", and the one you ruled out **is part of the answer too** —
  he has the right to overrule you. Quietly hold it back, and what you lose when he finds out is trust.
- **Do not report tasks without bugs** (and the other way round too). **"What is left to do" inherently includes "what is still broken".**
- **Do not give a number that does not add up.** Report "6 items" and the ledger has to really hold 6;
  **when the count is off, go reconcile before you answer.**

> If you cannot tell what the scope is, **confirm the scope before answering** — "are you asking about the whole project, or just VPN?"
> That is the one time to ask back; every other time what he wants is an answer.

## 4e. How the output gets to him: **put it in his hands, do not report a path**

The Requester's own words: "for example this thing of yours, 'the report is written: `claude-outputs/supervisor/xxx.md`' — **now I have to go open a folder and look for it**"
/ "**from now on every file you output should show up so I can click it and preview it on the right; putting it where the rules say is no problem**".

**Note the second half**: the file **goes where the rules say** (that is our business, not his); what he wants is **to see it without leaving this conversation**.

Any seat that produces a file — a report, a spec, a review record, a retrospective, a screenshot, a comparison image, a step sheet —
**must make it directly openable in the same reply**. The repo path is written beside it only as the archival record; **it is not the delivery**.

**Never give just a line of path.** That is telling him to go dig through a folder, and the machine in front of him may not even be that one
(he is on a phone, on another machine, or that machine happens to be stuck — which happened this very round).

**How to send it depends on what the platform this session runs on gives you** (putting a file into the conversation, generating a previewable page, an attachment…):
different platforms, different means, **but there is only one criterion, and it does not move with the platform**: **he sees the content without leaving this conversation.**

Three rules that go with it:

1. **Send the file + a three-sentence summary**; do not paste the whole text into the conversation again — either he reads the summary and decides whether to open it,
   or he opens it and reads the whole thing, and **two copies of the same content only burn his attention and tokens**.
2. **The file name stays `<date>-<one line>`** — he has to recognize which one it is at a glance in a list.
3. **Send it again after you change it.** The copy in his hands is the version you sent last time; change it in the repo without resending
   and what he is looking at is the old one, **and he will not know**.

## 5. How the Supervisor's input comes in

`claude-outputs/supervisor/` (committed as-is, nobody changes a character) → the Requester forwards it to the Reviewer → **the Reviewer verifies item by item** →
verification records go in `claude-outputs/reviewer/` → what holds up becomes a task/AD, what doesn't gets the evidence for rejecting it written down.

**Conflicts go only into the verification record, never into the task file development reads.** Development doesn't need to know which of the three parties was right, only what was finally decided.

## 5b. The advisory task (consult ticket) — **how the Reviewer seat's own decisions get an independent look**

**This closes a gap in the separation of powers**: architecture, the database, technology choices, the UI rules —
**the Reviewer seat sets them**; their implementation is **reviewed by the Reviewer seat**; and whether it passes is **judged by the Reviewer seat**.
One seat sets the standard and judges compliance with it, with no second pair of eyes in between.

**The Requester's own fix** (verbatim in `ai/rules/maintenance-log.md`):

> "Any spec or verdict the reviewer gives … I can just call it and pass it, but if I say something like I need to consult the supervisor,
> the reviewer sends the supervisor an advisory task, then I go and tell the supervisor to continue or to look at the task or something, and it reads it and gives an opinion and a verdict,
> back on the reviewer's side, I only have to say the supervisor has given its opinion and the reviewer can read it, and give a verdict again taking that into account"

**The key is that it fires on demand, not an extra round on every item.** By default you make the call yourself; **only when you ask for a consult** does the path below run.

### How it runs (five steps)

| # | Who | What they do |
|---|---|---|
| 1 | **The Requester** | Says one line to the Reviewer seat: "**consult the supervisor on this**" |
| 2 | **The Reviewer seat** | Opens an **advisory task**: `ai/tasks/T-####`, with `type: advisory` and `assigned to: supervisor`. **Use the existing task ledger, do not start a second one.** The task states: what it should look at, which constraints are known, and **which point you want it to challenge most** |
| 3 | **The Requester → the Supervisor seat** | Says "**look at the task**" or "continue" |
| 4 | **The Supervisor seat** | **Reads only the one assigned to it** (see below), gives its opinion and verdict → writes it into `claude-outputs/supervisor/<date>-<one line>.md`, leaves a line in the task file pointing at it, and pushes the status to `in review` |
| 5 | **The Requester → the Reviewer seat** | Says "**the supervisor has given its opinion**" → the Reviewer seat reads that output, **gives its verdict taking that into account**, then closes the advisory task |

### Three hard rules

- **This is the one exception to the Supervisor seat reading the queue**: when the Requester says "look at the task", it may
  `grep -l 'assigned to: supervisor' ai/tasks/T-*.md` to find its own entry, and **read only that one**.
  **It may not look at other tasks along the way, and it may not start scheduling from there** (`ai/roles/supervisor.md` §1).
- **Closing authority is the Reviewer seat's** (it opened the ticket). The Supervisor seat can only push to `in review`.
- **The Reviewer seat may decline to adopt it** — but it **must write into the task why it was rejected, with evidence**.
  This is the residual risk: the independent eyes looked, but whether it is adopted is still the Reviewer seat's call, and **the final backstop is the Requester**.
  So the verdict that comes out of step 5 is one **you can overturn outright**.

> **Why not "every AD gets a mandatory round of oversight"**: that would turn every technical decision into two rounds,
> doubling the cost while most decisions are not disputed at all. **Firing on demand** spends the cost on the few you genuinely doubt —
> the price is: **if you do not ask, there is no second pair of eyes**. Say that plainly, do not hide it.

### The retrospective material is not summarized by the seat under review

**The raw material** (verbatim quotes + a timeline, no assessment) comes from the seat under review, **committed under `claude-outputs/<seat>/`, never `tmp/`**; **the assessment comes from the Supervisor seat**, through the §5b consult ticket. **Why**: a self-assessment is written from inside the seat and **is structurally blind to a whole class of problem** (the evidence is in `claude-outputs/README.md`).

## 6. Priority

| Level | What | When |
|---|---|---|
| **P0** | Currently making the system unusable (a whole feature won't open, data will be lost, privilege escalation) | Jump the queue, same day |
| **P0** | Security (permissions, keys, injection) | Jump the queue, same day |
| **P1** | Bugs and small requests the Requester raises in person / already scheduled features | This stage |
| **P2** | Scheduled but blocking nobody | Next stage |
| **P3** | Tech debt, refactoring — **done in between, stoppable at any time** | When free |
| **P4** | Ledger hygiene, reconciling what's on the books | Keep it in mind |

**A `blocked` item takes no priority** — it's waiting on an external condition, not queued behind someone.

## 7. Four things the Developer must do at every stage's wrap-up (**a stage can hold several tickets**)

🔴 **"Pushing one ticket to `in review`" is not "this stage is over."** These four are the wrap-up of a **stage, done once**,
not something you repeat per ticket. Once a ticket is handed over, **open the next one immediately** — review is asynchronous:
the Reviewer reviews, you keep building. **A stage ends** when every ticket assigned to you has been pushed, or when you hit
one of the four reasons under "why I stopped here".
(Measured in the project this template came from: the seam between those two rules let the Developer wrap up after one ticket
while three more sat in the queue untouched — **each sentence was right, together they stopped early**.)

1. Update the paragraphs of `ai/state/now.md` this stage's changes touched.
2. Change the **"implementation" column of every AD** this stage touched (in the matching number-range file under `ai/decisions/`; don't miss one).
3. Push the task status to `in review`, with the five report subsections + **the "Self-test" section** written out; paste the **raw output** of the self-check and the self-test screenshots into `claude-outputs/developer/<date>-self-check.md`.
   **A failed self-test may not be pushed to `in review`.**
4. Write a one-line commit message at the end of `state/now.md`; the Requester copies it straight when committing.

Miss one of the four and whoever takes over next stage has to dig through the code to rebuild the current state — far more expensive than writing these four.

## 7b. Commit · write-back · sweep (**the whole section is in `ops/README.md`**)

Three rules; the detail and the commands are all in `ops/README.md`:

1. **Whoever made the change commits it**: the Reviewer seat commits when a round ends, **the Maintainer seat commits its own rule changes**, **the Developer seat does not commit**
   (committing your own work = bypassing the review). Run `bash ops/scripts/commit-round.sh "<title>"`,
   **`add` + `commit` only, never push**; **a red guard blocks the commit**; **the five SourceTree safety prohibitions**.
2. **What you change on the real machine must get back into the repo**: write back the same round + reconcile with `sha256sum -c`. If none of the four steps works, park it in
   `tmp/writeback-pending/`; **parked is not delivered, and the Reviewer seat may not pass it**.
3. **`conformance sweep`**: the Requester thinks things have drifted, the Maintainer seat runs `bash ops/verify/check-all.sh` and **answers with one table only**.
