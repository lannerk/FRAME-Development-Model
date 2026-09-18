# Decision index

| Item | Value |
|---|---|
| **Next available number** | **AD1** |
| Numbering rule | This line is the only allocation point, **whoever uses one adds one**. On a collision **the entry written later changes its number**, leaving one line in place saying "was ADxxx, renumbered to ADyyy after a collision"; the one already referenced in several places does not move. |
| Who maintains it | The Developer writes, the Reviewer comments; renumbering is the Developer's job |
| Entries | 0 |


## Split into files by number range

| File | What it holds |
|---|---|
| `AD0001-0100.md` | AD1 ~ AD100 |
| `AD0101-0200.md` | AD101 ~ AD200 |
| `AD0201-0300.md` | AD201 ~ AD300 |
| `AD0301-0400.md` | AD301 ~ AD400 |
| … | create whichever one you need |

**Why by number range and not by topic**: numbers are ordered, so **the split can be machine-checked** — nothing can be missed, nothing duplicated, no judgment required.
Automatic classification by topic was tried: most entries hit several topics, another batch hit none, and in the end a human still judged them one by one.
**The point of splitting into files is "don't read the whole ledger to see one entry", and number ranges solve that completely**; to read by topic, `grep` the tags below.
Create a number-range file when you need it; don't create seven at once.

## Topic tags (every entry carries one, for grepping)

| Tag | Scope |
|---|---|
| `network` | network-related |
| `<tag>` | `<split by your own project, eight at most>` |




| `hardware` | hardware and peripherals (delete this row if there are none) |
| `process` | the hard laws, the three roles, the document system, the ledger's own rules |

**One tag per entry** — the one for "where the main change lands". To find across topics use `grep -E 'network|system'`.

```
grep -h '| network |' AD*.md       # everything network-related
grep -h 'AD42' AD0001-0100.md      # look one up
```

## The common table header

```
| Number | Topic | What it settled | Decision state | Implementation | Details |
```

- **What it settled**: one line, **≤60 characters**, say "what was settled", not "why". The why goes in the details.
- **Decision state**: `✅the Requester's final call` / `✅called by the Reviewer on his behalf` / `⏳undecided` / `🗑superseded (replaced by ADxxx)`
- **Implementation**: `landed` / `landed · verified on the real machine (stage N)` / `partial (X done, Y in T-####)` / `to build` / `won't do`
  **Every stage's wrap-up must change this column** (`../rules/conventions.md` 8). A summary row covering many sub-items records no progress; write "the sub-items sit in the individual tasks".
- **Details**: `archived` = go search the number in `archive/`; can also be `../specs/xxx.md` or `../tasks/T-####-*.md`.

## How to add an entry

1. Take the number from above and **increment it immediately**;
2. Append a row at the end of the table in **the number-range file it belongs to** (the number is the ordering, don't insert in the middle);
3. **Don't write long narrative into the table** — write it into the related task or spec and put a signpost in the table.
   The ledger is a list of "what was settled", not an incident report. Entries of 2000 characters in the old ledger are the direct reason it grew to 738KB.

## 🗑 Superseded decisions

Don't delete: **change the state, note what replaced it, and leave it where it is**. Moving it makes every old document referencing it point at nothing. Whole batches that fall get named once here:

- A whole batch that falls (for example a technical direction is overturned and the batch of decisions derived from it all die) **gets named once here**,
  so nobody starts the next stage from a dropped decision.

