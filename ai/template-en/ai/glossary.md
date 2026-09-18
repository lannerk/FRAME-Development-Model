# Glossary — **the words machines read too**

> **Read this one before you translate this doc set.** See step 2 of `docs/guide/project-init.md`.
>
> The words listed here have two fates: **translate it and you change the scripts in the same round**, or **don't translate it at all**.
> Getting that wrong means **a guard fails silently** — the script still exits 0, but it is no longer looking at anything.
> **That way of breaking has no symptom**, which is exactly why this file exists.

## 1. **Do not translate** (not one character)

| Word | Where | Why |
|---|---|---|
| `BUILD-OK` `INBOX-OK` `CHECK-PATHS-OK` `TEMPLATE-SYNC-OK` and their `-FAIL` counterparts | output of the guard scripts | **Scripts talk to each other, and to people, through these strings**; translate one and the wiring breaks |
| `T-####` `AD####` | task number / decision number | Machines and people both search by them |
| Every directory name and file name | the whole repo | The structure has to work across languages |
| Code, variable names, JSON keys, config items, commands | `.sh` `.ps1` `.json` | They are code, not prose |
| `P0` `P1` `P2` `P3` `P4` | priority | Short, unambiguous, works across languages |

> Inside a script **the comments and the `echo` lines written for people can be translated** — but **don't touch those marker words inside the quotes**.

## 2. **Translate it and you change the scripts in the same round**

| Word | Who reads it | What to change when you translate it |
|---|---|---|
| `pending` (inbox state) | the `grep` in `ops/verify/check-inbox.sh` | Swap that word in the script for your translation too |
| `todo` `in progress` `in review` `passed` `blocked` `dropped` (task states) | Only people read them for now; the moment you add a script that "counts by status", they join this class | Same; and add a row to this table |
| `pending` `task opened` `answered` `won't do` (inbox dispositions) | Same | Same |

**Verify after changing**: deliberately create one record in the "unhandled" state, run `bash ops/verify/check-inbox.sh`,
**it must go red**; delete it, run again, it must go green. **Only both directions tried counts as having changed it correctly** —
seeing only the green half is the same as having verified nothing.

## 3. A translation must be **the same one throughout**

The same word gets exactly one translation across the whole doc set. Once it is settled, add it to the table below,
and the next person (or the next session) translates from it — **don't let each document translate on its own**.

| Original | Your translation |
|---|---|
| the Requester | |
| Developer seat / Developer | |
| Reviewer seat / Reviewer | |
| Supervisor seat / Supervisor | |
| Maintainer seat / Maintainer | |
| evidence | |
| guard (script) | |
| reverse assertion | |
| inbox | |
| ledger / decision | |
| promote | |
| verbatim quote | |
| self-test | |
| review and test | |

## 4. When you add a new word

**The moment you hard-code a word of your language into a guard script**, come back and add a row to section 2.
The cost of not doing it: the next project switches language and translates it, **and from then on the guard is a formality that nobody will ever notice**.
