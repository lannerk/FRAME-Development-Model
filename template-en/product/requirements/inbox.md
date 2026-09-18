# The inbox — every single thing the Requester said has a line here

> **The Requester talks only to the Reviewer.** Every bug he reports, thing he wants, question he asks, call he makes **goes into this table first**, not one sentence left out.
> **Append only, never delete a line.** When it's handled, change "Disposition" and "Status", **don't take the line out** — take it out and nobody knows the thing was ever handled.
> The table is below; new lines get appended at **the bottom of it**.

## The rules (the Reviewer follows them)

1. **Log it when you get it, that round.** Three things in one message from the Requester means three lines. **Don't wait for "I'll log it once I've sorted it out" — that moment is where the loss happens.**
2. **Quote it verbatim**, don't paraphrase. Paraphrase drops the **purpose** and leaves only the surface action, and the purpose is what tells you whether the approach is right.
   Long ones (a whole requirement, feedback with screenshots) go into `verbatim/<date>-<topic>.md`; put the file name + a one-line summary in the table.
3. **Every line must have a disposition**: turned into task `T-####` / turned into a spec / answered on the spot / recorded as a decision / won't do (**say why**).
4. **Before a review round ends, `pending` must be down to zero** — either it has somewhere to go, or it explicitly says "won't do + reason".
   Run `bash ops/verify/check-inbox.sh` while wrapping up; it lists the lines that still have no disposition.
5. **Go through them one by one when you reply to the Requester**: say where each one went ("these three I opened as T-0042/43/44, this one I suggest we don't do, because…").
   **Every single thing he raised gets an answer back**, even if the answer is "won't do".

## Statuses

| Status | What it means |
|---|---|
| `pending` | Just logged, no destination decided yet. **No line may still be in this status when a round ends** |
| `awaiting the Requester` | Needs his final call before it can be settled; the multiple choice has been put to him, waiting on the answer |
| `task opened` | The disposition column holds the task number |
| `spec opened` | The disposition column holds the spec file name |
| `answered` | It was a question, not work; answered on the spot |
| `won't do` | The disposition column **must say why** |

## The table

| # | Date | The Requester's exact words (verbatim quote) | Type | Disposition | Status |
|---|---|---|---|---|---|
| 1 | \<YYYY-MM-DD> | \<copy what he said in word for word; for a long one put `verbatim/xxx.md`> | bug / request / question / decision | \<T-0001 / specs/xxx.md / answered: … / won't do: …> | pending |

> There are only four types: **bug** (something is broken) / **request** (a new thing to build) / **question** (he is asking, not necessarily work) / **decision** (he made the call, record it as a decision).
> Can't tell them apart? Log it as `request` and fix it when you dispose of it. **The classification doesn't matter, not losing it does.**
