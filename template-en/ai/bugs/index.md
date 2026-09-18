# BUG ledger

> **One bug, one file**: `ai/bugs/B-####-<one line>.md`. This table holds the index only; the detail is in the file.
> **The closed rows are the "list of fixed bugs"** — regression testing re-runs them every round (`ai/specs/testing.md` §7).

**Next available number: B-0001** (once you use it, add one to this line)

## States

```
to reproduce ──reproduces──▶ reproduced ──task opened──▶ to fix ──developer reports──▶ fixed, awaiting retest ──reviewer retests──▶ closed
   │                                                                                                     │
   └──does not reproduce──▶ cannot reproduce (go back and ask the Requester for conditions, not dropped) └──retest fails──▶ to fix
```

Side branch: `won't fix` (write why + who made the call).

**Three things you must not do**:

- **If the four reproduction parts are not all written, it may not go to development** (environment / preconditions / steps / symptom). Make development guess the reproduction steps
  and a wrong guess means it fixes a different problem.
- **Development may not mark a bug `closed` itself.** It can push it to `fixed, awaiting retest`, **closing authority sits with the Reviewer seat** —
  whoever fixed it cannot test their own blind spots.
- **`fixed, awaiting retest` may not sit overnight into the next round.** If the developer report says "fixed a bug" at all,
  **the Reviewer seat must retest this round**, without waiting for the Requester to say "review and test".

## Severity

| Level | What |
|---|---|
| **S1** | Blocker: a whole block of functionality unusable / data can be lost / privilege escalation |
| **S2** | Major: the main flow runs but the result is wrong, or it happens every time |
| **S3** | Normal: intermittent, has a workaround |
| **S4** | Minor: looks, wording, corners |

## In flight

| # | Title | Severity | Source | Status | Related task | Found | Last movement |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

## Closed (= the ones regression testing re-runs every round)

| # | Title | Severity | Root cause in one line | Related task | Date closed | How the retest verified it |
|---|---|---|---|---|---|---|
| | | | | | | | |
