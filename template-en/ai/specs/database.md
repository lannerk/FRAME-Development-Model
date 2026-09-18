---
status: to be written by the Reviewer seat (skeleton by the Maintainer seat; the Maintainer does not fill in the content)
version: v0
last updated: 2026-09-15
decisions: —
referenced by: <registered both ways when a task is opened>
prototype: product/design/database/
owner: **Reviewer seat** (`ai/roles/reviewer.md` §2b)
---

# Database design

> The single source of truth for the table structure. **ER diagrams, table-relationship diagrams and images of that kind go in `product/design/database/`**; only the text definitions go here.
> A project with no database: write one line, "this project uses no database, the data lands in <where>", and **do not delete this file** —
> delete it and the next person asks the same question all over again.

## 1. What is used
The choice and its **version**, why, how connections and credentials are managed (**credentials are not written into the repo**).

## 2. Tables
| Table | What it stores | Primary key | Key indexes | Who writes, who reads |
|---|---|---|---|---|
| | | | | |

The field-by-field detail of each table goes below it; **for every field say whether it can be null, its default, and its unit**.

## 3. Relations and constraints
Foreign keys, unique constraints, cascade behavior. **Cascade deletes get named separately** — they are the likeliest to delete what should not be deleted.

## 4. Migration strategy
How a version goes up, whether it can roll back, **what happens to the data at release**.
**"Just rebuild it" is not a strategy** — in production there is no rebuild option.

## 5. Explicitly not doing
How far denormalization goes, which queries are deliberately unsupported.

## Change log
| Date | What changed | Why | AD |
|---|---|---|---|
