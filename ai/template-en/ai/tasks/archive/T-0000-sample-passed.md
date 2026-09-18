---
id: T-0000
title: [Sample] write in this format, don't build this content
raised by: Reviewer
assigned to: Developer
status: passed
priority: P1
evidence: AD<number>
spec: ai/specs/<name>.md
blocked on: —
opened: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

> **This is a sample**, left in the archive to show the format: what one task looks like from end to end.
> Two sections matter most: **"Where it differs from the suggestion"** (how the Developer pushes back with evidence) and **"Review verdict"** (how the Reviewer both adopts and rejects).
> The content is rewritten from a real case — "a guard was added, but the guard itself was broken"; that class of mistake is the one most worth reading once.

## What to do

Root-fix "some class of resource never gets initialized and a whole block of functionality is unusable".
The root cause is not one missed call, but **lazy initialization + modules piggybacking on each other's "whoever initialized first"**:
miss one entrance and you get a blank screen, and whether it breaks depends on which feature the user clicked first — **the same code behaves differently under different operation orders**, which is why it often cannot be caught in testing.

## How (suggested, may be rebutted)

1. Change it to **unconditional initialization at load time**;
2. Or, falling back: call it once on the first line of every external entrance, **and write a script that scans for misses**.
3. Either one is fine, but **it must come with a guard a machine can check** — an approach resting on "remember to call it next time" is not accepted; this class of problem has already come back once.

## Acceptance

- [ ] Stage a cold start that "goes through this one entrance only and touches nothing else"; the feature works
- [ ] The guard script goes red when one call is deliberately removed (**reverse assertion**, paste the output of the deliberately broken run)
- [ ] The syntax/build self-check passes

## Developer report

- **What was done**: took suggestion 1. The four modules each call it once right after their own init function is defined; that function is idempotent, so not one existing call site was removed.
- **Evidence**: `<file:line>` ×4; new guard `<script path>`.
- **Measured**: a cold start through one entrance only, all four stylesheets injected, feature complete (**the original symptom is gone**). Screenshot `claude-outputs/shared/screenshot/<date>-cold-start.png`.
- **Self-check output**: `claude-outputs/developer/<date>-self-check.md`.
- **Where it differs from the suggestion**: **did not write the scan script from suggestion 2** — once suggestion 1 was taken the first line of each entrance no longer needs the call, so there is nothing left for the scan to look for.
  The guard was pointed at "if an init function is defined it must be called at load time" instead, because the new failure shape is different: the call can no longer be missed; all that is left to break is "somebody bypasses it and writes their own".

## Review verdict

- **Round N (\<date>)**: **one item rejected, the rest pass.**
  1. Taking 1 over 2 is the better call and the reasoning holds — turning "can be missed" into "cannot be missed" is a grade above "a miss can be detected"; my option 2 was the fallback. **Adopted.**
  2. 🔴 **But the guard itself is fake**: its test cannot tell "a call at a module's top level" from "a call inside a function body",
     I deleted that top-level line and ran it once, **and it still came out all green, exit code 0**.
     **You wrote a guard but did no reverse assertion** — this item is rejected, opened as T-<number>.
  3. Record the lesson in `ai/rules/conventions.md`: a newly added guard must be run once on the spot against a deliberately broken case, with the output showing "it did go red" pasted in.

> What this sample really wants to say is item 3: **a guard script is code too, it can be wrong, and when it is wrong there is no symptom at all** —
> the self-check is green forever, you think you are protected, and you are not. That is why the "reverse assertion" is a hard requirement, not a formality.
