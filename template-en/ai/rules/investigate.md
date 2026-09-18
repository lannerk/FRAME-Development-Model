# How to investigate an "it's broken" — **the first-hour handbook**

> **Who reads this one**: **the seat holding a bug, or asked to locate a problem** —
> **the Developer seat and the Reviewer seat both read it** (development has to reproduce the problem and dig out the holes it dug itself; review has to investigate the case and judge pass or reject).
> It applies just the same to the Supervisor seat doing a focused survey.
>
> **Why it is a file of its own**: this is **generic method**, and it belongs to no one seat.
> It used to be written inside `ai/roles/reviewer.md`, and the Requester pointed out "the Developer sometimes needs to debug a problem and reproduce it too" —
> put something generic into one seat's handbook and the other seats cannot read it (the same point as the "who may change the rules" section of `ai/rules/layout.md`).
>
> **When to read it**: **the moment you get an "it's broken", before you touch anything.** Not at the opening — read it when you need it:
> one page, five steps, read it before you open your mouth.

> **This is the one file in these rules that is about how to investigate.** The Supervisor seat measured it: before it existed,
> the hit count for "elimination tree / falsification / pre-assertion" across the near six hundred lines of the opening read was **0** —
> a session does whatever it read, and so it **defaults to bookkeeping and passing the ball rather than investigating**.

**The main line of this round is "find out what is going on", not "get it all on the books".** The inbox still gets its one line per item in the same round, as the rules say (that one is not skippable),
**and every other bookkeeping job (retrospectives, specs, tidying the ledgers) waits** — what he is waiting for is "what is actually going on here", not a file with a complete format.

### 1. Split the symptom into sentences that **can be judged true or false**, and label which layer each one belongs to

"The whole browser stops responding" and "the page request spins forever" **are not one sentence** — the first is the browser's main thread, the second is the network connection.
**Different layer, different probe, different root cause.**
**The criterion**: the symptom section may not keep words like "frozen / not right / something is wrong" that cannot be judged true or false.

**Before you open a B number, `grep` the symptom's keywords once in `ai/decisions/` and once in `claude-outputs/`** —
two commands, and they keep you from walking a road someone else has already walked.

### 2. The three questions for a minimal reproduction environment (in order; stop at the first "yes")

| Question | What to do if yes |
|---|---|
| ① Pure front end (HTML / CSS / SVG / JS)? | **Start an http server in the container and run the real page** — no real machine, no login (`file://` blocks the sprite's fetch) |
| ② A pure function / a protocol / config parsing? | Run it straight in the container |
| ③ Does it genuinely have to be the real machine? | **Write down which one part of it is the part you need**: some process's running state / a piece of hardware / a piece of live data |

**The criterion**: the first line of the "Localization" section in the bug file has to be one of these three answers. **"Can't reach it" is not allowed** — that is hard law 7's business (see below).

### 3. Draw the elimination tree

At least two branches, each written as [how to rule it out · how long it takes · the result]. **No tree, no "root cause".**

### 4. Execute cheapest-first; **the first cut must be the ≤1-minute, zero-command one**

Switch window / incognito / hard refresh / another account / another port / a smaller file.
**The criterion**: if the first branch executed is not the cheapest, say why.
**A real one**: the cut "open the same address in another browser window" got ranked after reading Go source, guessing at disk space and guessing at time zones,
and was only tried when the Requester asked a third time — **it settled the case on the spot (200 / 13ms)**.

### 5. Three words, three grades (detail in "Three words, three grades, never mixed" below)

**Only once every branch of the elimination tree has a result may you write "conclusion".**

## The three investigation techniques, and the bar for troubling the Requester

### The three techniques

- **Pre-assertion**: on any reproduction rig, **prove first that the rig really got into the state you want to test**.
  If the pre-assertion is not green, every "did not reproduce" that follows is just an empty window.
- **Take the evidence under the same premises the user had**: DPR, browser, login state, zoom, window width.
  Comparing sizes requires **the same scale and the same crop box**; never put two renders of different widths side by side.
- **If you can enumerate, do not guess.** Enumerating once usually costs less than guessing three times.
- 🔴 **A test assertion is not proof of intent.** Finding that a test asserts the current behaviour
  **only proves somebody wrote it, never that it is right**. Judge **whether what that assertion protects is what the user wants**:
  an assertion usually pins an **implementation detail** (was this field mutated), while the thing to protect is
  **whether what the user sees is true** — the same "judge the thing being protected, not its textual shadow",
  **except that here the shadow lives in a unit test** (measured by the Reviewer seat on 2026-09-16: because a unit test
  asserted the current behaviour, a real bug was ruled "established behaviour, needs the Requester's call", twice in a row).
  **How to judge**: say out loud what the assertion protects and what the user wants; when they are not the same thing,
  **the assertion is itself part of the bug**.

### The bar for troubling the Requester (the executable version of hard law 5)

1. **Prove you cannot do it before you open your mouth** — paste hard law 7's three-row "which roads I tried" table. **Cannot fill in three rows, cannot open your mouth.**
2. **One step sheet per round, no more**: numbered · one command per step · what to paste back for each step · how many minutes in total ·
   ending with "**I will reply once it is all pasted back**". A second one in the same round → a violation, and it goes into the review record.
3. **A workaround is not a delivery** (see `ai/bugs/README.md`).

### "I cannot do it" is a negative conclusion too (hard law 7's criterion)

**"I cannot reach it / it has to be the real machine / I have not thought of a way yet / you will have to run it for me" — these are all negative conclusions.**
Before you say one, lay out **which roads you tried**:

| Channel tried | Result | Evidence |
|---|---|---|
| Whether it runs straight in the container / sandbox | yes / no | command + output |
| Read-only probing (browser, HTTP interfaces) | yes / no | the response or a screenshot |
| **Whether the same information is in the source** | yes / no | file:line number |

**Cannot fill in those three rows, cannot say you are unable.**
**A real one**: the skill-list item said "I have not thought of a way that does not need a shell", while three minutes of `grep` finds that GET interface in the source — **without touching the real machine**.

## The two sentences of a reverse assertion — the first one gets skipped

A reverse assertion has to prove **two things, and the order matters**:

1. **this path really is reached by this test**;
2. break it, and this test goes red.

**Do only the second and the test may never have executed the code under test at all** — it went red for another reason,
or it stayed green because it never got there.
**"I ran a reverse assertion" is the textual shadow; "this test really reached the code under test and went red" is the thing.**

**Two failure modes measured in practice** (diagnosed by the Developer seat itself on 2026-09-16, one variant per round):

| Variant | Shape | What it actually bit |
|---|---|---|
| A | The injected fault stops the program from **building at all** (compile / syntax error) | **The compiler**, not the logic under test |
| B | The injected fault sits on a **branch this test never reaches** ("broke something, but not on the step that would fail") | Nothing at all — **the assertion's precondition was never met** |

**Three criteria, written into the reverse-assertion record; missing one means it was not done**:

- what the **precondition** for reaching the code under test is, and how it was met;
- the red after breaking it is **on the assertion under test**, not the compiler and not some other assertion;
- **green again after putting it back.**

> **Why this one is worth the space**: a reverse assertion is the **only** way we have to show that a test is biting anything at all.
> Once it spins freely we are back to the "a test exists, therefore we are covered" illusion —
> **and that is worse than having no test, because it feels already verified**.

### Three words, three grades, never mixed

**Hypothesis** = an idea with no evidence behind it; it **must state "what action falsifies it and how long that takes"**, and it **may only appear inside the elimination tree**;
**measured** = there is command output / a screenshot / a number / a request and response; **conclusion** = writable only once **every branch of the elimination tree has a result**.

**In what you say back to the Requester, and in any ledger, only "measured" and "conclusion" may appear.**
A "conclusion" that keeps overturning itself has negative value to him.
**The criterion**: the moment "withdrawn / void / my earlier conclusion does not hold" appears, **it must say at the same time what that conclusion was based on originally**;
more than twice in one round → that round's verdict is downgraded to "undetermined".
