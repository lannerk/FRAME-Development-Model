# This project's own implementation discipline and delivery self-check

> **This file is project-owned content; it is `seed` in `ops/frame/classes.txt` -- a FRAME sync never overwrites it and never pushes it back to the source repo.**
> The general explanation, and why these sections exist at all, live in §3/§4/§5 of `ai/rules/conventions.md`; **the entries themselves live here**.
>
> 🔴 **Why it is a separate file** (the Requester ruled "split it out" on 2026-09-27): the entries in these sections are filled in per project.
> They used to sit inside `ai/rules/conventions.md`, which is `follow` (it travels with FRAME). Measured twice:
> **every distribution reported that file as "target changed" and needed a human merge**, and a project with `push=yes`
> would in turn **push its own commands into FRAME**. The criterion is "who does this content belong to":
> **generic belongs to FRAME, project-specific belongs to the project** -- split across two files, the mechanism never has to ask.
>
> 🔴 **Numbering continues from `conventions.md` and is never renumbered**: references elsewhere ("§4.22", "self-check #20") mean the numbers here.
> Renumber once and every reference silently points at a different rule. Append new entries at the end.
> 🔴 **A check specific to this project does not go in §5 and never means editing `ops/verify/check-all.sh`**: name it `ops/verify/check-project-*.sh` and it runs automatically.

## 3. Implementation discipline

> This section is project-specific. Write what you **actually agreed on**, don't copy generic software-engineering dogma —
> an entry with no incident behind it goes unread three months later. Directions to consider:

11. `<hard constraints on technology choices, e.g. "the backend uses the standard library only", "no third-party UI framework">`
12. `<real implementations, no mocks; a missing component honestly returns an empty state>`
13. `<which table a new interface/config item must be registered in>`
14. **Self-review the interaction loop**: before handing off, check that every state is complete (enter/exit/empty/error/first-use),
    that there are no extra elements (duplicate titles, unusable controls — delete them on the spot), and that no element is missing. **The Requester says 1; on interaction you think of 10 yourself.**
15. `<comment conventions: language, what a file header must say>`


## 4. Front end / interface (leave the section empty if there is no interface)

16. `<which file is the one source of style tokens; new code may not hardcode colors or numbers>`
17. `<controls of the same kind share one style system-wide; look for an existing control to reuse before making a new one>`
18. **For "changed it, no effect" holes such as caching and version numbers: make the value computed, then add a gate.**
    A rule that says "when you change X, remember to also change Y" **is worth nothing if a human has to remember it** —
    the project this template came from hit it twice in a row: the frontend file was pushed, its sha matched, the logs
    looked fine, and the browser kept serving the old one, because the version string had not been bumped.
    Do this instead: make the version string the fingerprint of that file's contents (first few hex chars of its sha256),
    and add a gate that recomputes and reconciles, with a `--fix` mode
    (`ops/verify/check-cachebust.sh` is that shape: three knobs, `CACHEBUST_WEB` / `_PAGE` / `_PREFIX`, and it **skips itself when it does not apply** —
    the project-specific slots have to be knobs; hard-code them and the next project just gets a false red).
    🔴 **Strip carriage returns before hashing**, or the same content fingerprints differently on a Windows checkout
    and the gate goes red for no reason.


## 5. Pre-delivery self-check (missing one means it isn't done)

> **This is the most important section**: it defines what "done" means.
> Every entry should **come out of one command**, with no human judgment. Paste the raw output into `claude-outputs/developer/`.

| # | What to run | Which incident left it |
|---|---|---|
| 19 | `<build>` | `<has a file that doesn't compile ever sat in the repo?>` |
| 20 | `<static analysis>` | |
| 21 | `<tests>` | |
| 22 | `<checks specific to this project, e.g. syntax scan / path reconciliation / rule lint>` | |

