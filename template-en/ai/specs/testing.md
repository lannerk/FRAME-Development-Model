---
status: to be filled in (the template ships the skeleton)
version: v0
last updated: <date>
decisions: —
referenced by: <registered both ways when a task is opened>
prototype: —
owner: **Reviewer seat** (`ai/roles/reviewer.md` §6). It sets them, it maintains them.
---

# How this project is tested

> **Why this file exists**: the eight kinds in `reviewer.md` §6 say "**what to test**", and that part is generic;
> "**how to test**" differs for every project — some need a test machine driven remotely, or a debugger attached inside some engine,
> some need two clicks in a browser and that is it. **Settle the means here once, then test from it and keep it updated as it changes.**
>
> **The Reviewer seat fills this in before it starts testing.** Kinds you cannot fill in still keep their row, saying what is missing before they can be tested —
> **blank means you never thought about it**, and the kind nobody thought about is the kind that gets missed later.

## How to fill it in

Write four things for each kind; miss one and that kind does not count as settled:

| What to write | Meaning |
|---|---|
| **Means** | What you test with (clicking in a browser, driving a test machine remotely, sending requests, attaching a debugger, running a script…) |
| **Environment** | Which machine you test on. **Reference machines by the `id` in `ops/machines.json`, never a hard-coded IP**; for how to connect see `docs/ops/realmachine.md` |
| **Action** | Which command to run / which path to click / what request to send. **Someone else must be able to re-run it from this** |
| **Evidence** | What is left behind afterwards: command output / request and response / screenshots / numbers. Put it in `claude-outputs/reviewer/<date>-testing/` |

## §0 What to test: the generic eight (moved from `ai/roles/reviewer.md` §6)

| # | What to test | What counts as tested |
|---|---|---|
| 1 | **Feature testing** | Walk the task's "acceptance" items one by one, marking each pass/fail; for failures give the **minimal reproduction steps** |
| 2 | **UI acceptance** | Compare item by item against the finalized prototype and the UI rules: layout, font size, spacing, color tokens, **empty / loading / error / disabled states**, narrow screen, dark mode. **Screenshots as evidence** |
| 3 | **Interface testing** | **Really send the requests**: normal + missing parameters + over-length + unauthorized + duplicate submission. Record method / path / status code / response body fragment |
| 4 | **End-to-end operation testing (E2E)** | Just **click all the way through the way a user would**. Mandatory: going back mid-flow, refreshing, double-clicking, dropping and reconnecting the network, doing it again on another account |
| 5 | **Performance testing** | **Only counts with numbers**: cold start, first screen, interface p50/p95, memory and CPU, whether they creep up over a long run. State which machine it was measured on |
| 6 | **Case coverage** | **Only if there is a case library**; if not, write "this project has no case library yet" and skip it — do not manufacture one |
| 7 | **Regression testing** | For the shared dependencies this change touched, **re-run whatever is using them**; **a bug that was fixed must be re-run once** — it is the likeliest to come back |
| 8 | **Full test pass** | When the Requester says "full", or **before a release / a build**: the whole case library + a walk through every critical flow |

### The hard rules of testing

- **A test is a conclusion too, and comes with evidence the same way.** Command and output / request and response / screenshot / numbers — **one of the four**.
  "I tested it, no problems" does not count as tested.
- **State up front what this round tests and what it does not**, with a reason for the untested ones (environment not available / outside this round's changes).
  **A vague "tested everything" is far more dangerous than an honest "these four were not tested".**
- **Test in the real environment.** If you cannot test it, say you cannot; do not write "should be fine" as "verified".
- **Land every problem you find on the spot**: into the inbox / opened as a task / recorded as a decision. **Said only in conversation is the same as not said.**
- **The no-changing-feature-code rule does not move.** Find a bug and open a task for development; **do not fix it yourself** — whoever fixes it cannot test their own blind spots.
- Test verdicts go into **the same task file**, as a "Test verdict" section next to "Review verdict".
- There are only three verdicts: `pass` / `pass with follow-up` / `reject`. **"With follow-up" must be backed by a `T-####`**, otherwise it is a reject.

> **Development self-tests too** (`developer.md` §5), but that is **him looking at the feature he built himself**.
> The value of your testing comes from **you not having written this code** — so do not just re-run the few things he ran; **go for the corners he would not think of**.

## §0b The layered probe table — whichever layer you suspect picks the probe

**Every row has to give a yes / no inside 1 minute.** This section is filled in by the **Reviewer seat**; the Maintainer seat only builds the structure.

| Layer suspected | Probe | How to read it | Last actually run |
|---|---|---|---|
| Browser main thread | | | `<date>` |
| Browser connection quota / cache | | | |
| The front-end logic itself | | | |
| The front end × the back end interaction | | | |
| Whether the server side is locked up | | | |
| Whether the server-side process is alive | | | |
| Whether the scene is still there | | | |

**Two attached rules**:

1. **Every row carries "the date it was last actually run"** — otherwise in three months nobody knows whether it still holds.
   (A real one: the `--strip-components` in `docs/ops/realmachine.md` was wrong, and typing it as written errors out on the spot.)
2. **Collect the evidence first, restart afterwards.** Restart the service and the stack is gone; **the original scene only happens once**.

> **The Supervisor seat's 2026-09-15 audit came with a filled-in candidate table** (in `claude-outputs/supervisor/`),
> **but it declared itself that it had only run three of the rows**. Per §5, "how the Supervisor's input comes in":
> **the Reviewer seat verifies row by row, actually runs it once and notes the date, and only then does it move into this table.**

## The eight kinds

### 1. Feature testing
- Means:
- Environment:
- Action:
- Evidence:

### 2. UI acceptance
- Means:
- Environment:
- Action:
- Evidence:

### 3. Interface testing
- Means:
- Environment:
- Action:
- Evidence:

### 4. End-to-end operation testing (E2E · click all the way through like a user)
- Means:
- Environment:
- Action:
- Evidence:

### 5. Performance testing
- Means:
- Environment:
- Action:
- Evidence:

### 6. Test cases and coverage
- Where the case library is (if there is none write "none yet", and say when you plan to build it):
- Means:
- Action:
- Evidence:

### 7. Regression testing
- How the scope is drawn (which shared dependencies the change touched → who is using them):
- **The list of fixed bugs**: the "closed" table in `ai/bugs/index.md` (**re-run these every round**). Write here how you plan to run them in bulk:
- Action:
- Evidence:

### 8. Full test pass
- What triggers it (the Requester says "full" / a release / before a build):
- Action:
- Evidence:

## Change log

| Date | What changed | Who |
|---|---|---|
| `<date>` | opened | Reviewer seat |
