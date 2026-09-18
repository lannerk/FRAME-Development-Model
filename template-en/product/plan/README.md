# Development plan

> **Who writes it**: the Reviewer seat. **Who makes the final call**: the Requester.
> **When you need one**: a requirement too big to **fit into one task** — it has to be split into batches, ordered, spread across several features — gets a plan before any task is opened.
> Small changes go straight to a task, **don't manufacture a plan just to follow a process**.

| File | What it is |
|---|---|
| `roadmap.md` | **The milestone master table**: which milestones exist, what each one aims at and how it's accepted, where things stand now |
| `milestones/M-##-<name>.md` | One file per milestone: scope, which tasks it splits into, dependencies, risks, what counts as done |

## Three rules

1. **A plan is not a task queue.** The plan says "how many batches and why this order"; what actually gets done lives in `ai/tasks/`.
   The two point at each other by number: the milestone file lists `T-####`, the task file writes `milestone: M-##`.
2. **Every milestone must have a "done" that can be accepted** — the kind you can prove with a command or a screenshot.
   A milestone with no acceptance criteria is a wish, not a plan.
3. **Plans change, and you change the original.** Reordering, cutting scope, adding a batch — **change that one file + add a change-log line**,
   no opening a `roadmap-v2.md`. Say clearly why it changed (the Requester's call, or measurement overturning it).
