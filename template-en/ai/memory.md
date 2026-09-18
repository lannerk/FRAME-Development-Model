# Project memory — things said once that hold from then on

> **One of the opening-read files, so it has to stay short (cap 80 lines).** The rules govern "how to collaborate", `docs/` governs "procedure and detail",
> **and this one governs only the seven things below**. **All four seats read it, all four seats may write it** (only the Maintainer may change the rules; **anyone may record a memory**):
> the Requester hands over something project-specific → **record it the same round, and reply "recorded in project memory"**.
> **Whether to record is this seat's own call — you do not ask the Requester to approve it**: memory is a record, not a decision (his words, 2026-09-15: "project memory is for the role itself to decide whether to record, it does not need to ask me"). **Changing a rule is what has to go through the Maintainer seat.**

## Record only these seven

| # | What to record | What it looks like written down |
|---|---|---|
| **1** | **Information you need constantly** | The ops page address · **which** token gets you in and **where to find it** · a service's real unit name and port · which machine must not be rebooted |
| **2** | **A specific situation handled a specific way** | "Hit **X** → do **Y**" plus one line of why |
| **3** | **A fix you worked out yourself** | "**I solved it with Z this time**, next time the same thing, do Z" — **the whole point of recording it is so you don't have to go round the houses again** |
| **4** | **Mistakes you have made, once verified** | "**writing it this way is wrong: … the correct way is: …**" — the Requester's own words: "**record a wrong approach once you have verified it, so nobody makes the same mistake again**". **Shared by all four seats — one seat steps in it, none of the others has to** |
| **5** | **His preferences and red lines** | What format he wants · when not to interrupt him · **which things he must do himself** (pasting a key / a password / logging in) · approaches he has explicitly said he dislikes. **This is the class a new session loses first, and losing it means he has to teach it again** |
| **6** | **Quirks of the environment and the platform** | Undocumented facts: the mounted share is case-insensitive · one platform judges typing into a web terminal as remote execution and blocks it · `curl` from the cloud container to the real machine gets 403. **Not a wrong approach (type 4) — "this is just how it is here"** |
| **7** | **Glossary mapping** | His words ↔ the actual module / file / service. **Misreading his terms does not raise an error; it only shows up as a delivery that missed** |

**Every entry carries "verified on <date>"** (the same reasoning as the layered probe table): **the token's location changes, platform policies change**,
and three months on nobody knows whether that entry still holds. **An entry with no date is one the next person dares neither trust nor delete.**

**Two sources**: ① what he told you (types 1, 2); ② **what you worked out yourself** (types 3, 4, 6) — the latter is the one that gets lost,
**a method you only found after going round the houses, left unrecorded, means going round them again next time**.

## Do not record these

The Requester's own words: **"if the memory duplicates the rules there is no need to remember it."** Likewise not recorded:
**development detail and procedure steps** (the rules and `docs/` already hold those; at most leave a one-line pointer here) · **credentials themselves** (see 🔴 below) ·
**"how far things have got"** (`now.md`) · **"why it was decided that way" and "proposals that were raised and rejected"** (both in `ai/decisions/`, whose AD entries already have a "what was rejected" column) · one-off accidents that **will not recur in another form** (a wrong approach that will recur is type 4, and must be recorded).
**When it is full, move the paragraphs into `docs/` and leave a one-line pointer — the value of this file is that it is short.**

## A worked example that sits right on the boundary

"Where the test machine is and how to upload things" has three things in it, **and they go three separate places, no duplication**:
which machine and what address → **`ops/machines.json`** (the single source; documents reference it by `id`);
the upload **steps** → **`docs/ops/`**; **which token gets you in, where to find it, which box to paste it into** → **this file**.

**That is what the criterion looks like**: do not record duplicates, **record only the bit the rules do not cover and that you need every time**.
**Everything named above is an example, not a checklist** — the criterion is the three types, not those particular items.

## 🔴 Credentials themselves never land on disk

**Record "which token, where to find it, which box to paste it into", not its value.** The value is **pasted by the Requester himself** (hard law 5's red line).

**The one exception: a machine the Requester has explicitly exempted.** When he rules "the credential for *this* machine lives in the repo and travels with git", **do as he says, and record that he exempted it, with his own words, in section 1** — **never move it again and never ask him for it again**. **The exemption covers only the machine he named**: a new or added machine, or production, and the red line applies as before.
Written correctly it reads: "Uploading on the ops page `<address>` needs the 'upload token'; it is at `<where>`; **the Requester pastes it himself, the AI keeps no copy**."

---

## 1. What all four seats need to know

| # | What (tag the type 1-7) | Source · **verified on** |
|---|---|---|
| | | |

## 2. What only one seat needs to know (subsections: developer / reviewer / supervisor / maintainer)

**If you cannot tell, put it in section 1** (same as the four-seat cross-cutting case in `maintainer.md` §3b).

---

**Append only, never delete a row.** Strike through what no longer holds and say why: `~~original~~ — <date> no longer holds: ...`
