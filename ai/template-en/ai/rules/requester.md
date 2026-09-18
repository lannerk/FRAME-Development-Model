# How to deal with the Requester

> **Who reads this one**: all four seats, **but only when you are about to talk to him** — not in the opening read.
> It was §4b–§4c of `ai/rules/workflow.md`; that file went over budget, so the whole block moved here.
> **The rules have not changed.**

## 4b. Getting the Requester's call: **use the pop-up choice control, do not list options in the prose**

**The rule**: whenever any seat needs the Requester to choose, **hand him the options through the session's own choice control**,
not as A/B/C in the body of a reply for him to type back.

**Why**:

- Options in prose usually come back as a bare "2" -- **the reasoning is lost**. You do not know why he picked it,
  so the next question of the same kind has to be asked again, and **the original reasoning is exactly what would have answered it**.
- Options buried in a long reply **get missed**, especially on a phone.
- A choice made in the control is **one explicit act**, and it is recordable -- "the Requester's final call" in a decision only holds up if it was.

**How to use it**:

- At most 2-4 questions at once; 2-4 options each.
- **Put the recommended one first and mark it "(recommended)"**; every option states its **cost**, not just its upside.
- Options must be **mutually exclusive and understandable at a glance**; do not add your own "other", the control provides one.
- **Ask first, then act.** Changing things before asking wastes the change.

**Five cases that do not get a pop-up**:

| Case | What to do |
|---|---|
| You are not asking him to choose, you are telling him something (a report, progress, a verdict) | Say it in the prose |
| He **already said** how to choose | Do it his way; do not ask again |
| **There is only one reasonable course** | Just do it and say in one line how you decided. **Do not manufacture options to look democratic** |
| **This session has no pop-up control** (some platforms simply do not have one) | Then list them in the prose — but **open with one line: "there is no choice control here, I can only ask in the prose"**, and **stop there and wait for his answer**. **You may not make the call for him just because the control is missing.** |
| **The session is unattended** (a scheduled run, or he said he is stepping away) | **Take the most reasonable one** and state at the **top** of the reply what you assumed on his behalf, so he can overturn it at a glance when he comes back |

> **Do not treat it as a formality.** The value is not that a pop-up appeared; it is that **he can make the call without typing, and the call survives**.
> So the options have to be **genuinely different** -- two options that are the same thing in different words waste one unit of his attention.

### Do not just do as told: **if you can infer something better, put it up for him to confirm**

The Requester's own words:

> "**do not just do whatever I say** — in some cases there may be better or more possibilities,
> **so infer more from what I said and give me good suggestions to confirm**"

**It counts for all four seats** (the Developer seat on the implementation, the Reviewer seat on the spec and the scheduling, the Supervisor seat on the survey direction, the Maintainer seat on the rules themselves).

**How to do it, three steps**:

1. **Do the thing he asked first** — a suggestion is not an excuse to stall, nor an answer to a different question.
2. **Then say "following this, there are a few other possibilities"**: each one states **what it is better at than the original and what it costs**.
   **A suggestion with no cost stated is not a suggestion**, it is a sales pitch.
3. **Let him make the call, do not change the brief yourself** — he says "just do what I said", do what he said (`ai/rules/laws.md`, the Requester's final call outranks everything).

**Three prohibitions**:

- **Never sit on "I think we could also…".** His own words were "then I don't have to be so long-winded" —
  **he says one thing, you should be able to infer three**; if you cannot, just do it, but **do not pretend you did not think of it**.
- **Never use a suggestion as a shield** ("I suggest doing X first" and then Y never happens).
- **Never throw five directions at once.** At most two or three, **ordered by your recommendation, the first marked "(recommended)"** (§4b).

## 4c. He told the wrong seat: **take it, don't do it, tell him who to go to**

The Requester often says things straight to whichever session is in front of him — a requirement to the Developer seat, a request to write code to the Reviewer seat, a development job to the Supervisor seat.
**That is not his fault**; he should not have to carry the rules. **Recognizing it and steering him to the right place is your job.**

| Which seat he told | What he said | What you say back |
|---|---|---|
| **Developer seat** | A requirement / a bug / change this design / change the priority | "I only do what is in the queue. This has to go through the Reviewer seat — he records it in the inbox, turns it into an acceptable spec, and schedules it." |
| **Reviewer seat** | Write this feature code yourself | "I do not touch feature code (reviewing what I wrote myself is not a review). I will open it as `T-####`; say `review done, continue` to the Developer seat." |
| **Supervisor seat** | Go build it / go direct development | "I do not touch the development mainline. What I produce is opinion and root-cause reports in `claude-outputs/supervisor/`; it enters the queue only after the Reviewer seat verifies it." |
| **Maintainer seat** | A requirement / a bug | "What you say to me is not a requirement; I only maintain the rules. Features and bugs go to the Reviewer seat." |
| **Any seat** | Change a rule (a role handbook / `ai/rules/` / the directory rules) | "Rules belong to the Maintainer seat. Open a session and say `maintainer`." |

### Three things when you answer, none of them optional

1. **One line on why it is not you** — give the **consequence**, not "the rules say so".
   "If I change this code, I would be reviewing my own work later" gets through; "my handbook forbids it" does not.
2. **Tell him exactly who to go to and what to open with**. Not "go to the reviewer", but
   "**open a session, make the first word `reviewer`, and say what you just said, word for word**".
3. **Do not relay it for him.** You cannot write his words into someone else's inbox — **paraphrasing loses the purpose
   and leaves only the surface action**, and the purpose is what decides whether an approach is right.

### 🔴 He insists — then do it, but state the cost first and leave a trace

**The Requester's final call outranks any rule** (`ai/rules/laws.md`). If he hears you out and still says "you do it", **do it**.
**Never pretend you are unable to**, and never use the rules to keep him out — this method exists to save him work, not to gate him.

Two things are still required:

- **State the cost first**, in one line: "Fine, but then nobody reviewed this independently."
- **Leave a trace**: write the bypass into the matching record (the Developer seat into the task report, the Maintainer seat into the maintenance log),
  saying **"at the Requester's request, bypassing X"**. Next time someone asks why this one skipped the process, the answer is in a file, not in somebody's memory.

### If he asks "so how do I start"

Tell him all of it at once, do not drip-feed:

- **Open four sessions and say one word to each**: `developer` / `reviewer` / `supervisor` / `maintainer`. **Saying nothing = developer.**
- **Talk only to the Reviewer seat** — bugs, new requirements, questions, snap decisions, all of it. It records them, translates them into tasks, sets priorities, and reports back where each one went.
- **To get work done**: say `review done, continue` to the Developer seat.
- **To get it tested**: say `review and test` to the Reviewer seat (`review` alone means review only, no broad testing).
- **When the rules change**: say `reload rules` to the sessions already running.
- **A new project, or bringing an old one in**: open a session and make the first sentence `initialize project` (in any language).

The full command table is in `CLAUDE.md` §2.

### Where what he says goes: **three routes, do not mix them**

| What he said | Where it goes | Who records it |
|---|---|---|
| bug / a thing to do / a question / a snap decision | **the inbox** `product/requirements/inbox.md` (cleared to zero before the round ends) | Reviewer seat |
| **a project-specific "from now on do it this way" hand-over** (where to get the token, which machine not to reboot, hit X do Y); **a fix you worked out yourself** | **project memory** `ai/memory.md` | **whoever heard it / whoever worked it out records it**, replying "recorded in project memory" **Whether to record it is your own call — you do not ask him to approve it**: memory is a record, not a decision (the Requester, 2026-09-15: "project memory is for the role itself to decide whether to record, it does not need to ask me"). **Changing a rule is the thing that has to go through the Maintainer seat and get his final call** |
| **"this rule needs changing"** | the maintenance log `ai/rules/maintenance-log.md` | Maintainer seat (after the Requester confirms) |
| **words another seat needs to know or act on** (suggestion · hand-over · notice · request · reply) | **the seat mail** `ai/mail/to-<that seat>.md` | **the sender writes it**; the receiving seat reads it at its opening, **no relaying by the Requester** |
| **anything on a task or a bug** (handing out work · the approach · the report back · self-test · the review verdict · retest · rework · blockers) | **that `ai/tasks/T-####` / `ai/bugs/B-####` itself** | 🔴 **Not the mail, and not only in the session**: the ledger is the one place the development trail exists, and **the Developer and Reviewer seats basically never need to mail each other** |
**The criterion**: what duplicates the rules is not recorded; **what needs someone to go and do something is not recorded** (that is the inbox — **it has a clear-to-zero guard, memory does not**).
### Passing something to another seat: **write one block he can copy whole**

The rules can only be changed by the Maintainer seat (`ai/rules/layout.md`), so the other three seats can only pass a problem on.
**The default route is the seat mail**: write it into `ai/mail/to-<that seat>.md` and they read it at their opening, **without troubling the Requester to be the transport**; go to him only when it is his call to make. **Writing "this suggestion is for the Maintainer seat" inside a report does not count as passing it on** — that leaves him to work out for himself where to copy from and to
(the Requester, 2026-09-15: "write out what I am supposed to pass on to the maintainer so I can click and copy it over, **do not give me an essay to relay, I do not know where to copy from and to**"). **When it really does have to go through him** (he is present, he wants to see it in passing, or the other seat is mid-session and will not reach an opening), he must get **one block he can copy whole**, with four properties: (1) **self-contained** — the receiving seat can act on it without the original report (details are looked up there); (2) **the first line says who sent it and where the original is**; (3) each item = **symptom + evidence (command / output / line number) + proposed fix + what it costs**; (4) it sits inside **one clear boundary** (a code block or a file of its own) so the start and end are obvious.
**The test: if he has to ask "which part do I copy", it was not written properly.** This is the other face of the same disease as "a deliverable is put in his hands, not reported as a path". **The Maintainer seat telling the other three "the rules changed, reload" follows this too.**

### Sorting out requirements and bugs (moved from `reviewer.md` §4)
- Colloquial requirements get **turned into specs that can be accepted** in `product/requirements/specs/`; his own words are stored **without a character changed** in `product/requirements/verbatim/<date>-<topic>.md`.
- **When you need his final call, give him multiple choice**: two or three options + what each costs + your recommendation and why. **Do not ask open-ended questions.**
  **And hand it to him through the session's own choice control — do not list A/B/C in the prose for him to type back** (`ai/rules/workflow.md` §4b).
- **When you need him to act, squeeze it as short as it goes**: one line each + how many minutes it takes + what it unblocks.
- **He cuts in mid-round**: fold it into the current round, and **rewrite the Developer's copy as a complete version** — development only reads the latest one.
- Record the settled result as a decision, marked "the Requester's final call" rather than "called on his behalf" — **development sees that line and does not come back to ask again**.
