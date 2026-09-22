# Seat mail — how to send, how to read, what does not belong here

> **Read this one on demand** (when you are about to send, or unsure whether something belongs here); **it is not in the opening read**.
> What the opening read covers is your own `ai/mail/to-<your seat>.md`. Guard: `bash ops/verify/check-mail.sh`.

## It is not the same thing as the other ledgers (**the easiest thing to mix up**)

| What is being passed | Where it goes | Why not the mail |
|---|---|---|
| What the Requester said (a requirement / a bug / an ad-hoc decision) | **the inbox** `product/requirements/inbox.md` | those are his words, and it has a clear-to-zero guard |
| **Everything between the Developer and Reviewer seats about tasks and bugs**: handing out work · the approach · the report back · self-test · the review verdict · retest · rework · leftovers · blockers · missing conditions | **a task** `ai/tasks/T-####` / **a bug** `ai/bugs/B-####` | 🔴 **Almost nothing between these two seats goes through the mail.** The ledger is where the live truth is; **putting it in the mail pulls the development trail out of the ledger** (the Requester, 2026-09-15: "otherwise the development trail gets lost"). The guard reports **any letter between these two that mentions `T-####` / `B-####`** red |
| a bug itself (symptom / reproduction / locating / fix / retest) | **`ai/bugs/B-####`** | same as above |
| project knowledge of the "from now on do it this way" kind | **project memory** `ai/memory.md` | memory is long-term and for everyone, not a one-off note to one seat |
| where a rule change finally lands | **the maintenance log** `ai/rules/maintenance-log.md` | that is the record after the change; **the suggestion before it goes through the mail** |
| **cross-seat suggestions / hand-overs / notices / requests / replies** | **the mail** `ai/mail/to-<recipient>/from-<sender>.md` | this is the one |

### 🔴 Developer seat ↔ Reviewer seat: **they basically never need to mail each other**

The Requester, 2026-09-15: "**the Reviewer and the Developer basically have no need to mail each other; the cases are very few**";
"**handing down a requirement, reporting a bug, building the requirement, fixing the bug, reporting back — all of it happens through the project's existing agreed way of working together**".
**The default answer is "do not send".** From handing out work to closing it, a task lives in `ai/tasks/T-####` (and the `ai/bugs/B-####` it is tied to) —
**that is the one place the development trail exists**, and anyone taking over can read the whole line there. The mail only carries things **unrelated to a specific task**:

| May be mailed | May not (goes in the ledger) |
|---|---|
| "I cannot reach the real machine's terminal from my seat — can your read-only probe grab a stack for me": a **capability / channel** question | "T-0031 is done" / "B-0001 retested" |
| "from now on I can reproduce this class of front-end bug in a container, stop waiting for the real machine": a **method agreement** (which also belongs in `ai/memory.md`) | "I disagree with this approach because ..." (that goes in the task's "how to do it (suggested, arguable)") |
| A rule-level suggestion (**but that is addressed to the Maintainer seat**) | "what else is there to do / what bugs are open" (the Reviewer answers the Requester from the ledger) |

**The test, in one line**: **does this sentence belong to some `T-####` / `B-####`? If it does, write it in that file and do not send a letter.**

The guard adds two stricter rules for this pair: **only "request" or "notice" are allowed** (suggestion / hand-over / reply all mean task talk is happening),
and **at most 1 unhandled letter** (a second one means the mail is being used as a development channel).

🔴 **The mail is not where work is handed out.** A letter that just names a `T-####` / `B-####` and tells the other seat to go do it
belongs in the ledger in the first place — the guard reports it red. **The mail carries words; the ledger carries work.**

## What a letter looks like

The mail lives in **`ai/mail/to-<recipient>/from-<sender>.md`** — three drop-boxes per seat, twelve in all: **one file per sender, nobody touches anyone else's, so there are no git conflicts** (the Requester, 2026-09-15: the archive has to be one file per seat; by the same logic the drop-box is only really split once it is split down to the sender). **The sender is already in the filename, so a letter no longer carries a "From" column** — the same fact is never written twice.

**One row is one letter**, and none of the five columns may be empty (write `—` when there is nothing):

| Column | How to fill it |
|---|---|
| Date | `YYYY-MM-DD`, the day it was sent |
| What I have to do | **one line, starting with a verb**, so the recipient knows what to do after reading it. **Never just an ID** |
| Where the detail is | a path, several allowed; anything **longer than three lines becomes a file** and the letter carries only the path (the file goes in `claude-outputs/<sending seat>/<date>-<topic>.md`). If three lines really covers it, write `—` |
| Type | suggestion / hand-over / notice / request / reply |
| Reply needed | yes / no |

**Each drop-box is capped at 12 lines** (about 6 letters); full does not mean raise the cap, it means **nobody reads it or the letters are too fragmented**. **A letter left unhandled for 7 days goes red**: either handle it, or the sender withdraws it and takes another route.

**Four rules for sending** (the same criteria as "passing something to another seat" in `ai/rules/requester.md`):

1. **Self-contained** — the receiving seat can act on it without the original report; details are looked up at the path.
2. **One letter, one thing** — otherwise it cannot be handled or archived on its own.
3. Each item = **symptom + evidence (command / output / line number) + proposed fix + what it costs**.
4. **Sending is not doing** — delivered is not done. **After sending, say one line in the session** (the Requester, 2026-09-15: "when A sends B a letter, A also has to report the sending in the session"): **who it went to · one line of what it says · where the detail file is**; that line tells him the thing has been handed over, **so he does not have to relay it**.

> **The overall logic of sending, receiving and archiving** (as the Requester set it out on 2026-09-15): A adds a row to `to-B/from-A.md` → **A says "sent to B: ..." in the session** → B reads it at its next opening (or when the Requester says `check mail`) → **B reports the mail summary in the session** → B handles it → **B moves that row into its own `archive/B-<YYYY-MM>.md`** (the archive belongs to the recipient; **a letter belongs to whoever it was sent to**).

**To everyone**: the sender **writes one row into each of the other three seats' `from-<itself>.md`**, and each seat reads and handles its own.
(No "the last reader deletes it" — one missed read and it never gets deleted, and you cannot see who it is stuck on.)

## 🔴 One round trip is the limit (so nobody loops)

The Requester, 2026-09-15: **"this needs a boundary, otherwise it can turn into an endless loop of replies"**.

**There is only one case that deserves a reply: reading the letter raised a new question you cannot settle yourself.**
(His words: reply when "there is a new question in the letter's content that cannot be solved and needs asking again";
"if it has already been settled or you decided it yourself, no reply is needed"; "a notice like 'reload the rules' needs no reply either".)

| After you handled it | Reply? |
|---|---|
| You did it / you settled it yourself / you turned it into a task | **No** — **the archive row is the receipt**, the sender can look it up in `archive/` |
| A notice (the rules changed, the templates are synced, a machine moved) | **No** |
| You refuse it | **One "reply" letter with the reason**, and only that one |
| Reading it raised a new question you cannot settle | **One "request" letter** that asks it properly |

- **A "reply" and a "notice" must themselves carry "reply needed: no"** — the guard reports it red.
- **If it cannot be settled, change tracks**: open a `T-####` / `B-####` for work, or an **advisory task to the Supervisor seat**
  (`ai/rules/workflow.md` §5b). **The mail is not a chat room**; it only puts one thing into the other seat's hands.
- **No second round because "you did not convince me"**. Still deadlocked = the Requester has to call it; write it into his inbox.
- **No courtesy receipts** ("got it", "thanks", "great suggestion") — that is a token-burning loop with no content. The guard reports it red.

## 🔴 Look at the other mailbox before you send (no flooding)

The Requester, 2026-09-15: "a sender sending one role several letters, or the same letter while it is still unread — **there has to be a mechanism that stops the sending**". So read `to-<them>/from-<you>.md` first (you only ever look at your own file):

| What you see | What to do |
|---|---|
| You already sent this thing and they have not handled it | **Edit that letter** (or the file it points at). **Do not send another.** The guard reports the duplicate red |
| You already have 3 unhandled letters to them (non-notice, all in your own file) | **Stop.** This is not them being slow, it is **you using the mail as a ticket system** — open a task or an advisory task |
| Your own file is already at 12 lines | Same as above: **wait for them to clear it, or change tracks now** |

**Notices (such as "reload the rules") may not be repeated either**: after three rounds of changes, edit that one letter's date and content — **the recipient will act once.**

## How to read and how to handle

**The first thing at the opening** is reading your own directory `ai/mail/to-<your seat>/` (three files, one per sender). The command word `check mail` means the same thing.
The way to read it is **three steps, not one reaction per letter**
(the Requester, 2026-09-15: "the way a role reads mail is to read it all at once, summarize and de-duplicate it itself, then judge whether anything needs doing"):

0. **First copy what you read into your own `archive/<my seat>-<YYYY-MM>.md`** (outcome "in hand" for now), **then act** —
   letters are live files written by another seat and **can be withdrawn or rewritten at any time**; this really happened on 2026-09-15: by the time the handling was done the originals were gone, and they had never been committed.
1. **Read it all at once** — **all three files together** (`cat ai/mail/to-<your seat>/from-*.md` is easiest); do not act on letter one before seeing letter five.
2. **Summarize and de-duplicate yourself**: **one thing gets done once**. If the Maintainer seat changed the rules three rounds
   and sent three "reload the rules" notices, you **reload once**, archive the rest together, and the archive row says `did it: duplicate of the row above, handled together`.
3. **Then handle them oldest first** — the order only affects the order of handling, never steps 1 and 2.
4. **Report a short summary in the session** (the Requester, 2026-09-15: "when it knows how to handle them, show that in the session too"):
   **how many letters arrived → how many distinct things after de-duplication → what happens to each**. Like this:

```
Mail: 3 letters (Supervisor x2, Reviewer x1), 2 distinct things after de-duplication
1. Supervisor - three rule suggestions (claude-outputs/supervisor/<date>-audit.md) -> doing it, this round
2. Reviewer - asks me for a write-back step list -> turned into T-0036
(letter 3 is the same thing as letter 1, handled together)
No replies needed: none of them is "a new question I cannot settle"
```

🔴 **Report an abnormal inbox instead of carrying it**: if one sender has **more than 3 non-notice letters** sitting unhandled (the guard reports it red),
or the same thing keeps arriving, **tell the Requester and the sender after checking the mail**: "stop sending it here; this belongs in a task or an advisory task".
There are only three ways to handle a letter, and **when you are done you move that row out of the mailbox into `ai/mail/archive/<my seat>-<YYYY-MM>.md`** (append one row, with the outcome) —
🔴 **the archive belongs to the recipient**: a letter the Maintainer seat sent to the Supervisor seat is archived by the **Supervisor seat** into `supervisor-<YYYY-MM>.md` — **a letter belongs to whoever it was sent to**, and the sender archives nothing (to look up what you sent, read the recipient's file). Archive header: `| Date | From | What had to be done | Where the detail is | Outcome |`.
**one archive per seat, not one shared file**: a shared file means all four seats appending to the same end of the same file, and **a git conflict is then a certainty** (pointed out by the Requester on 2026-09-15):

| Outcome | When | What the archive row says |
|---|---|---|
| **Did it** | it can be done this round | `did it: <what you did>` |
| **Turned it into work** | it is something that needs scheduling | `turned into T-#### / B-####` |
| **Refused** | not mine to do, or I disagree | `refused: <reason>`, and **send one "reply"** back |

🔴 **Before moving, renaming or deleting a mailbox or archive file, `wc -l` it for data rows**; if it has any, **move the content first and only then remove the shell** — **judge what is inside the file, not what its name looks like** (a real case, 2026-09-15: judged "an empty shell" by its name and deleted, taking two archive rows the Supervisor seat had already written outcomes into; recovered only via `git show HEAD:`. The guard now enforces "the archive may only grow").
🔴 **Another seat's live file may only be appended to, never rewritten whole** (later the same day, "restoring" that archive by rewriting it whole overwrote the version the Supervisor seat had just written — uncommitted, so not even in git). **To add a row, append; to change someone else's row, talk to them first.**

🔴 **Never mark it "read" in place.** The mailbox holds unread only — **read letters piling up is how the next person stops reading carefully**
(that is exactly how the inbox rotted once). The archive exists so that later you can answer "did anyone ever deal with this letter, and how".


## 🔴 The Researcher writes only to the Supervisor (the R&D line)

The Researcher on the R&D line is an **extra seat** (`ai/roles/researcher.md`): it **reads the whole repo and writes only
under `ai/RandD/`**, so anything outside that has to go **through the Supervisor**. It therefore **stays out of the four-seat
drop-box matrix**; there is exactly one pair:

| Drop-box | Who writes it | What goes in |
|---|---|---|
| `to-supervisor/from-researcher.md` | Researcher | asking for something outside `ai/RandD/` to be changed · asking for a cross-topic fact to be recorded in `ai/memory.md` (the Researcher cannot write it) · notice of a graduation request |
| `to-researcher/from-supervisor.md` | Supervisor | opinions · reminders · notices. 🔴 **Exploration is never sent back**; only converged output is, against the criteria, naming the one that failed |

**A drop-box nobody uses is worse than none** (it makes people think they may post there), so the gate reds both
`to-researcher/from-<anyone but the Supervisor>` and `to-<anyone but the Supervisor>/from-researcher`. Its archive is `archive/researcher-<YYYY-MM>.md`.
🔴 **When its letter needs a long body, it points into `ai/RandD/<topic>/`** — `claude-outputs/` is the four development seats' scratch area; the Researcher does not write there.

## One boundary you have to know

The mail is only read when that seat **next opens**, or when the Requester says `check mail` / `reload rules`.
**A session already running does not wake up by itself.** So for a notice like "the rules changed",
besides sending the letter you also ask the Requester to say `reload rules` to the running sessions (which now checks the mail as well).
