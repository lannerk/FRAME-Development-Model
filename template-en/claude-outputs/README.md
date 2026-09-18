# claude-outputs/ — Claude's scratch area

This holds **everything Claude produces while working**: screenshots, measured output, prototypes, one-off reports, drafts for the Requester, research notes.

**Why it gets its own directory**: these things have to be citable in conversation off the cuff ("look at `claude-outputs/shared/screenshot/xxx.png`"),
but they **are not the project's formal files** — formal files have a fixed home, a life cycle, and someone maintaining them.
Drafts dumped into the formal directories wash them out; drafts scattered through conversations can't be found again. So they get a place of their own.

## Where things go

| Subdirectory | What goes in |
|---|---|
| `developer/` | Raw output of the self-check list, measured data, delivery notes, build logs |
| `reviewer/` | Review records, work orders, write-ups of real-machine feedback, verification records for the Supervisor's output |
| `supervisor/` | The Supervisor's reports, proposals and topic research — **committed as-is, nobody changes a character** |
| `maintainer/` | The Maintainer's acceptance questions and score sheets, rule change notes — its **maintenance log** is not here, it is in `ai/rules/maintenance-log.md` |
| `shared/prototype/` | Interactive prototype html, rendered mockups |
| `shared/screenshot/` | Real-machine screenshots, UI comparison images |
| `shared/measurement/` | Measured numbers, scan listings, reconciliation results |

**Naming is always `<date>-<one line>.<extension>`**, date first so it sorts, e.g. `2026-09-16-VPN-six-state-render.png`.

---

## ★ The promotion table — where it moves once the Requester says "we're taking this"

**Adopted = from now on someone maintains it, it gets referenced, and it has to be updated along with the implementation.** So it has to leave the scratch area.
Three things happen together when it moves: **move the file → add the file header → register a line in the matching index**.

| What it is in the scratch area | Where it moves once adopted | What else to do |
|---|---|---|
| **A technical spec / an implementation plan** | **`ai/specs/<name>.md`** | See "§ Promoting a technical spec" below |
| **A research report** (option comparison, upstream capability research) | Fold the conclusion into the matching `ai/specs/<name>.md`; the original report stays in the scratch area | Point the spec's "evidence" back at the original report's path |
| **A write-up of the Requester's exact words** | `product/requirements/verbatim/<date>-<topic>.md` | **Not a character changed**; the Reviewer works up `product/requirements/specs/<feature>.md` alongside it |
| **A spec that can be accepted** | `product/requirements/specs/<feature>.md` | Record an AD in `ai/decisions/`, marked "the Requester's final call" |
| **A formal requirement item R-xx** | `product/requirements/formal/` | Update the feature list and statuses in `docs/features.md` |
| **A feature's prototype / design / icons** (the directory the Reviewer named in the scratch area, moved whole) | **`product/design/prototype/_PROJECT_/feature/<same-named directory>/`** | See "§ Promoting a design" below |
| **A whole prototype suite** (= a mirror of the running state, e.g. desktop, installer) | `product/design/prototype/_PROJECT_/suite/<suite>/` | Run the prototype self-check when done; the parts of `src/<project>/web/` that mirror it must be synced |
| **Confirmed UI baseline assets** (icon SVGs, color scheme, annotated images) | `product/design/ui/` | Tokens go into the project's token file, and must be visible on the style overview page |
| **Reference designs / competitor screenshots** | `product/design/reference/` | Nothing |
| **A rule meant to hold long-term** (a new engineering convention) | Add an entry to `ai/rules/conventions.md` | Record an AD alongside it saying which incident it came from |
| **Revisions to the architecture notes / directory notes / ops manual** | The matching file under `docs/` | Run `ai/check-links.sh`; broken links must be 0 |
| **System architecture design** | `ai/specs/architecture.md` (`docs/architecture.md` keeps only the reading guide) | Every change gets **its own AD** — it is the ground other people make decisions on |
| **Database design** | `ai/specs/database.md`; ER diagrams and other images in `product/design/database/` | Same as above; the migration strategy goes in there too |
| **Technology choices** | `ai/specs/tech-stack.md` | Spell out the **versions**, why it was picked, and **what got rejected**; same as above, record an AD |
| **Development plan / milestones** | `product/plan/roadmap.md` + `product/plan/milestones/M-##-<name>.md` | The milestone lists `T-####`, the task writes `milestone:`, the two point at each other |
| **Scripts** (self-check, audit, build) | Ones that travel with the source go in `src/<project>/tools/`; deployment and ops ones in `ops/scripts/` | Any that join the Developer's self-check list must be registered in `ai/rules/conventions.md` §5 |
| **A one-off investigation report / root cause analysis** | **Doesn't move**, stays in the scratch area | Write the conclusion into the relevant task's "Review verdict" or the "do not step on these again" section of `ai/state/now.md` |
| **Real-machine screenshots / measured output / self-check logs** | **Doesn't move**, stays in the scratch area | They are evidence; task files reference them by path |

---

## § Promoting a design (once the Requester has confirmed it)

**The draft stage**: the Reviewer works in `claude-outputs/reviewer/<name it yourself>/` — icons, images, html prototypes, notes; change them freely, no registration needed.

**Once the Requester confirms it**, the whole directory moves to:

```
product/design/prototype/_PROJECT_/feature/<same-named directory>/
                         ↑           ↑         ↑
                  src subdir name  fixed   the scratch-area name, unchanged
```

e.g. `claude-outputs/reviewer/VPN/` → `product/design/prototype/_PROJECT_/feature/VPN/`

Three things happen together when it moves:

1. **The whole directory goes over, name unchanged** — the name is the only thread between it, the draft, and the task.
2. **Add a `README.md`**: status, date finalized, decisions, what is inside, **how development is meant to use it** (build the prototype to match / take the icons as-is, don't draw your own / the boundaries and acceptance points in the notes).
3. **Fill `prototype:` in the task files that use it**, pointing at this formal path.

**Once it has moved**: the copy in the formal directory is the **only authority**; the scratch-area copy stops being updated, **and no formal file may reference it any more**.
To change the design, change the one in the formal directory (it gets updated along with the implementation), not the one back in the scratch area.

> **The Developer recognizes only paths under `product/design/`.** A `claude-outputs/` design path showing up in a task file
> means the task was opened too early — the design isn't finalized, go back to the Reviewer.

## § Promoting a technical spec (once it is confirmed or updated)

**The draft stage**: the Reviewer writes it in `claude-outputs/reviewer/`, changing it however he likes.

**Once the Reviewer and the Requester have confirmed it**, it moves to **`ai/specs/<name>.md`**, and:

1. Add the file header (status `settled` / version / last updated / decisions / referenced by);
2. Register a line in the "in use" table of `ai/specs/index.md`;
3. Fill `spec:` in the task file, pointing at it.

**Every later update happens inside `ai/specs/`**, never back in the scratch area: bump the version + write a change-log line + leave a reminder line in each open task that references it.
**Once a spec is settled it is "required reading before you start"**; when the implementation diverges from it, **change the spec** — don't leave it frozen on the day it was proposed.

---

**Deciding whether it moves comes down to one question: will anyone come back and change it later?**
Yes → move it to a formal directory; it needs a maintainer and an index.
No → leave it in the scratch area; it is the evidence of this moment, and the more untouched the better.

## Cleanup

The scratch area **grows forever** (in the old structure it hit 55MB / 83 files). Two rules:

1. **Tidy it once a quarter (or every 10 stages)**: move everything no longer referenced by any task file, as a batch, into `archive/claude-outputs/<year-quarter>/`.
2. **Don't delete** — they are in git too, but keeping them is faster than digging through git. Moving them out just keeps the current directory readable.

## Three prohibitions

- **Don't reference the scratch area as if it were a formal directory**: formal files in `ai/specs/` and `docs/` may not use a scratch-area path for anything except "evidence".
- **Don't change any file under `supervisor/`** — to correct something, the Reviewer writes a separate verification record in `reviewer/`.
- **Don't put binary output here** (executables, installers, images) — those go in `dist/`, uncommitted.

---

## The Reviewer seat's six kinds of design output, and where each lives

> The full text, moved here out of `ai/roles/reviewer.md` §2b. The handbook keeps only a table and a one-line pointer.

The Reviewer seat is not only "judging whether someone else got it right" — **what the system looks like is yours to set too**:

| Your job | Where the finalized output goes | Who makes the call |
|---|---|---|
| **System architecture** | `ai/specs/architecture.md` (the single truth); `docs/architecture.md` keeps one page of pointers to it | Requester |
| **Database design** | `ai/specs/database.md` (tables, fields, indexes, migration strategy); ER diagrams and such go in `product/design/database/` | Requester |
| **UI design** | Rules and baseline assets in `product/design/ui/`; the prototype and icons of a specific feature in `product/design/prototype/_PROJECT_/feature/<name>/` | Requester |
| **Technology choices** | `ai/specs/tech-stack.md` (what was chosen, **which version**, why, and what was rejected); **record a separate AD for each choice** | Requester |
| **Breaking down raw requirements** | Verbatim in `product/requirements/verbatim/` → acceptable spec in `product/requirements/specs/<feature>.md` → tasks in `ai/tasks/` | Requester |
| **Development plan for a large requirement** | `product/plan/roadmap.md` + `product/plan/milestones/M-##-<name>.md` | Requester |

**Three rules that apply to all of them**:

1. **Draft first, promote after.** All of it is done in `claude-outputs/reviewer/<name it yourself>/`, and only **after the Requester confirms** does it move to the column above, with a line registered in the matching `index.md`. After promotion **only the formal copy gets edited** (`claude-outputs/README.md`).
2. **Architecture, database and technology choices: every change carries an AD.** They are the ground other people stand on when they decide things, and **when the ground moves without notice, everything above it falls**.
3. **The criterion is always "is it the same thing in the user's eyes", not "is the change big"** — same thing means **update that one file**, never open a `-v2`. (Same rule as for designs and technical specs.)

### When a plan is needed

A requirement that **one task cannot hold** — needs batches, needs an order, spans several features — gets **a plan before the tasks**.
A small change goes straight to a task; **do not manufacture a plan to look procedural**. How to write one: `product/plan/README.md`.

### Source layout: **follow the language, not this template**

Inside `src/<project>/`, **organize by that language's or framework's own official convention** —
Go gets `cmd/` `internal/` `pkg/`, Java/Maven gets `src/main/java`, Python gets a package directory plus `pyproject.toml`,
a frontend framework gets whatever its scaffolding generates.

- **Do not impose another language's habits**, and do not invent your own layout to make things "look tidy".
  Breaking the language's convention costs you **its entire toolchain** (build, test discovery, packaging, IDE indexing),
  and every newcomer has to learn your version first.
- **Write which convention this project uses into `ai/specs/tech-stack.md`**, with a pointer in `docs/repo-layout.md`.
- This template governs what is **outside** `src/` (`ai/` `product/` `docs/` `ops/`); **inside is the language's business**.

---

## Producing a design / a spec: draft first, promote after confirmation (moved from `reviewer.md` §4)

- **The draft stage** happens in `claude-outputs/reviewer/<name it yourself>/` (icons, prototype html, notes) — change it freely, no registration needed.
- **Once the Requester confirms**, move it per the two promotion rules in `claude-outputs/README.md`:
  - design files → `product/design/prototype/_PROJECT_/feature/<same-named directory>/`, add a README, fill in `prototype:` in the task,
    and register a line in `feature/index.md`
  - **Before moving, confirm with the Requester: is this a new feature, or an update to an existing one?** The test is "is it the same feature in the user's eyes",
    not the size of the change. If it is an update, **change that directory directly + add a line to the change log**, and **do not open `xxx-v2/`**
  - technical spec → `ai/specs/<name>.md`, add the file header, register it in `specs/index.md`, fill in `spec:` in the task
- **Once promoted, the copy in the scratch area is left alone.** To change a design or a spec later, **change the one in the formal directory** —
  change both and development will not know which to trust.

---

## The retrospective material is not summarized by the seat under review (moved from `workflow.md` §5)

When the Requester wants a retrospective: **what the Reviewer seat hands in is the raw material** — verbatim quotes + a timeline, **with no assessment**,
**committed under `claude-outputs/reviewer/`** (**never `tmp/`**: `tmp/` is not committed and is cleared every stage,
and `ai/rules/layout.md` §6 says in so many words "nothing in `tmp/` may be referenced by anything").
**The assessment comes from the Supervisor seat**, through the consult ticket of §5b.

**Why**: a self-assessment is written **from inside the seat**. A real case — the Reviewer seat's nine-point self-assessment was perfectly sincere,
but of the six further points the Supervisor seat caught it had listed **not one**, and those six all happened to be visible only **from outside the seat**
(a workaround passed off as a delivery / something findable in the source treated as needing the real machine / half a mechanism used to overrule the Requester's observation / a lagging ledger / evidence left in `tmp/`).
**A self-assessment is structurally blind to this kind.**
