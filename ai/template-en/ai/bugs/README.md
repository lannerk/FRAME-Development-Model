# How a bug moves — a closed loop, nobody may break it in the middle

> This section used to be `ai/rules/workflow.md` §3b; that file went over its budget, so the whole section moved here.
> **The rules have not changed**, they just moved next to the thing they govern. The index is in `index.md`, one file per bug.
>
> **Before you start investigating, read `ai/rules/investigate.md` first** (the first-hour handbook, five steps) — **the Developer seat and the Reviewer seat both read it**.

🔴 **Everything on a bug is written in that bug's file, never in the mail** (symptom · reproduction · locating · fix · retest · rework) — **the Developer and Reviewer seats basically never need to mail each other**; the mail only carries things unrelated to a specific bug (`ai/mail/README.md`).

Bugs and tasks are two separate ledgers: **a bug records "what's broken and how to reproduce it", a task records "who fixes it and what it should become".**
A bug lives in `ai/bugs/B-####-<one line>.md`, the work of fixing it in `ai/tasks/T-####`; the two point at each other.

### Bug file template (copy it, all four reproduction pieces required)

```markdown
---
id: B-0007
title: The list goes empty after opening the settings panel and going back
severity: S2                 # S1 blocker / S2 major / S3 normal / S4 minor
source: Reviewer seat testing            # Reviewer seat testing / Requester / Developer seat / Supervisor seat
status: reproduced                # to reproduce/reproduced/to fix/fixed, awaiting retest/closed/cannot reproduce/won't fix
task: T-0042           # write — if there is none
found: 2026-09-15
closed: —
blocked on: —          # only "fixed, awaiting retest" may use it; which **external condition** it waits on
cleared by: —          # who can produce that condition. Write both lines or neither
---

## Reproduction (**missing one of the four and it may not go to development**)
- **Environment**: machine `<the id in machines.json>` / version / branch + commit
- **Preconditions**: which account, which data, which switches, what network state
- **Steps**: 1. … 2. … 3. … (**someone else following them reproduces it**; never write "did some stuff")
- **Symptom**: expected `<…>`, actual `<…>`; attach screenshots / logs / request and response
- **Reproduction rate**: 3/3 or 1/5 (**an intermittent one must be spelled out**, or development will think it fixed it)

## Localization (Reviewer seat writes; may be empty)
Which layer you read down to, where you suspect, **with line numbers or measurements**. If you aren't sure, leave it empty; don't write a guess as a conclusion.

## Fix (Developer seat writes)
- **Root cause**: why it happens. **Never write "added a check"** — that's the technique, not the cause;
  **by the same token a workaround (another window / incognito / a different port) is not a root cause either** — it answers "how do we get by for now", not "why does this happen"
- **What changed**: file + line numbers
- **Self-test**: the result of rerunning the "Steps" above exactly as written

## Retest (Reviewer seat writes; **only this section can close it**)
- **Round N (date)**: rerun the original steps → pass / fail
- **What got regressed along the way**: the shared dependencies this change touched, and who else uses them
```

### Four origins, four paths

| Origin | The first thing the Reviewer seat does |
|---|---|
| **Found by the Reviewer seat's own testing** | **Open a B number on the spot**, all four reproduction pieces filled in. Can't fill them in means you didn't test it clearly either — go back and finish |
| **Reported by the Requester** | Into the inbox first (one line each), **then reproduce it once yourself**. Reproduced → fill in all four and move it to `reproduced`; **cannot reproduce → open a B number marked `to reproduce` and go back to the Requester for the missing conditions** (which machine, which account, which step). **Never dump an unreproduced bug on development to guess at** |
| **Found by the Developer seat** | Have him open a B number (`source: Developer seat`) and not widen the current change on his own |
| **Raised by the Supervisor seat** | Verify item by item per §5; **verifying means reproducing it once** |

### When it goes to development, he must get three things

The task file fills in `bug: B-####`, and development **reads that file before starting**. From there he gets:
**what the bug is (symptom), how to reproduce it (steps), and under what conditions it appears (environment + preconditions).**
**Missing any one of the three, the task should not go out.**

### The development report gets one extra line

Add **`Bugs fixed:`** to the report, filled with `B-####` (write `none` if you fixed none).
Once it's fixed, push that bug to `fixed, awaiting retest`; **never mark it `closed` yourself**.

### The retest fires automatically; the Requester doesn't have to ask

**As long as "Bugs fixed" in the development report is not `none`, the Reviewer seat must retest those this round** —
rerun the original steps in the B file; **the Requester does not need to say "review and test"**.
Only after the retest passes do you push the bug to `closed` and record it in the ledger's "closed" table; if it fails, send it back to `to fix` and append another round in the same B file.

### 🔴 When the retest genuinely cannot happen: put it on hold, do not let it drag

Some `fixed, awaiting retest` bugs wait on **an external condition the Reviewer cannot produce** --
"actually install from the disk once", "the Requester plugs in a second cable". Then fill in both
header lines:

```
blocked on: an actual install from the disk
cleared by: the Requester
```

The guard then lists it as **⏸ on hold and does not count it as a break**, instead of mixing it into
the same red as "nobody retested". **Why separate them**: under the old test that red was permanent,
and **a permanent red is no red at all** -- nobody reads it any more and the real breaks hide behind it
(measured by the Reviewer seat on 2026-09-23: all 14 remaining ones waited on real hardware, and that
one red it could not clear was blocking even its own `--seat` commit).

**Three boundaries; drop one and this becomes the new dumping ground:**

1. **Write both lines or neither.** "blocked on" alone is a hold with no owner, so nobody knows who to
   chase -- which is exactly how it rots there.
2. **Only "fixed, awaiting retest" may be put on hold.** "to fix" means not fixed yet and "to reproduce"
   means not reproduced yet; writing "blocked on" there is granting yourself an exemption.
3. 🔴 **On hold is not an archive**: more than **21 days** without movement goes red anyway
   (`BUG_BLOCKED_MAX_DAYS` is the knob), and "without movement" is judged by **the last git commit time**
   (mtime is reset by a single clone). When it expires, pick one: retest because the condition arrived ·
   chase the person who can produce it · or rule it "won't fix" and write down why.

> **Why the retest isn't tied to a command word**: the command word governs "whether to test broadly",
> while "is the thing that was fixed actually fixed" is **something you must know every round**.
> Tie it to the command word and you get "the Requester didn't say test, so nobody knows whether it's fixed" —
> that bug comes back two rounds later as "it's happening again", and by then nobody remembers its original reproduction steps.

## "reproduced" does not mean "the root cause is known"

**`reproduced` only says you can make it happen again.** The bug file **allows, and encourages,** this combination:
**status `reproduced` + root cause `undetermined`**. The task you open then is an **investigation task** ("find the root cause of X"), not a fix task.

**Never write up a mechanism that explains half the symptoms as the root cause just to have something to show.**
The test is simple: **list the symptoms one by one; if your mechanism cannot explain any one of them, it is "undetermined".**
A real one: "the whole browser stops responding" and "the request spins forever" are two layers, and **a mechanism that only explains the latter may not sign off on the former**.

## A workaround is not an investigation result

A workaround **may only go in the "## Mitigation" section**, **it may not appear under "Next steps"**,
**and it may not be a reason to push the status forward or to lower the severity**.
The Requester's own words: "**just telling me to use incognito mode works around it, but working around it is not itself what investigating the bug needs,
what it needs is finding a way to reproduce it or to predict what the possible cases are**".

## The "Localization" section has three fixed subheadings

```
### Can it be reproduced locally   ← the three questions of step 2 of the first-hour handbook; the answer must be one of them
### Elimination tree               ← at least two branches, each with [how to rule it out · how long · result]
### Conclusion or current hypothesis   ← "conclusion" only once every branch has a result
```

**For a front-end bug, "Can it be reproduced locally" must carry the reproduction rig's output**, or say why it does not apply.

## Where the Reviewer seat stands on this line (moved from `reviewer.md` §6.4)

A problem you find **gets a B number on the spot** (`ai/bugs/B-####-<one line>.md`), with **all four reproduction parts written out**:
environment / preconditions / steps / symptom. **If they are not complete you may not pass it to development** — without the conditions to reproduce it, what he fixes is a different problem.

- **Bugs the Requester reports**: into the inbox first, **then you reproduce it once yourself**.
  Only once you can reproduce it does it move to `reproduced` and get a task; **if it does not reproduce, mark it `to reproduce` and go back and ask him what conditions are missing** (which machine, which account, which step),
  and **do not dump an unreproduced bug on development to guess at**.
- **Handing it to development**: fill in `bug: B-####` in the task, and he will read that file before starting.
- **Retesting is automatic**: if "which bugs were fixed" in the development report is not `none`, **you retest this round**,
  re-running the original steps from the B file, **without waiting for the Requester to say "review and test"**.
- **Closing authority is yours alone.** Development can only push to `fixed, awaiting retest`. Only after the retest passes do you push it to `closed` and register it in the ledger;
  if it fails, send it back to `to fix` and append another round inside the same B file.
- The closed ones **are the regression list**, re-run every round (§6.2 item 7).

For the detailed procedure and the file templates, see `ai/rules/workflow.md` §3b.
