# The kickoff advisor (`ai/advisor/`)

> **Who reads it**: **any seat** (the four plus the Researcher), the moment the Requester starts a new
> project, raises a new requirement, or asks "how should this be done".
> The procedure is in `ai/rules/requester.md` §4d, "think it through for him, then ask him".
> **This is part of FRAME itself** (class `follow`, updated by a sync). 🔴 **Only judgements that hold on
> another project belong here** — brand names, product names, repo names, people's names and private
> source IDs may not enter (`ops/verify/check-advisor.sh` scans for them).
> **Where it comes from**: rulings accumulated on real projects, **abstracted into generic practice**;
> whatever was specific to those projects stays in their own profiles.

## What this is

Someone using FRAME may not be a technologist, and may not know what a project even has to decide.
**The kickoff advisor makes every seat think the plan through before answering**: the approach, the
choice of stack, why this is recommended and what happens otherwise; and the dimensions he never
mentioned (internationalization, compatibility with an existing system, secrets, AI, licences …) get
**raised on purpose**, each option with its cost and a marked recommendation.

## When to use it (five triggers)

| Trigger | What to read |
|---|---|
| A new project / module / product line | the profile → pick questions from `questions.md` → the relevant `domains/*` and `stack.md` |
| A requirement of some size | the profile → `chains.md` for what it drags in → the relevant `domains/*` |
| A new requirement appearing mid-project | the profile → `chains.md` (he said A, so put B and C on the table too) |
| "How should this be done" / "is there a newer way" | earlier rulings in the profile → `stack.md` / `domains/*` → the best answer; if it differs from before, say why |
| Initializing a project | walk through `questions.md` and write the answers into the empty profile |

**Never read it whole**: read the profile first (usually one page), then look up the one section you need.
**It is not in the opening read.**

## Two layers, fixed priority

| Layer | Where | Whose | Open-source? |
|---|---|---|---|
| **The Requester's profile** | `product/requirements/requester-profile.md` | this project (class `seed`: the template ships an empty skeleton) | ❌ never flows back |
| **The generic advisor library** | `ai/advisor/` (this directory) | FRAME itself (class `follow`: a sync updates it) | ✅ |

🔴 **The profile outranks the library.** What he has already settled there is **used, not asked again**, with
one line in the body saying which of his rulings were applied; the library only fills in where the profile
is silent. **A recommendation in the library is not a default** — anything that is his call still gets asked.

## The files

| File | What is in it |
|---|---|
| `principles.md` | Generic product principles (judgements that hold across projects) |
| `questions.md` | The kickoff question bank: each question = why ask it · what happens if you do not · options and their cost · what to recommend when he has no preference |
| `chains.md` | Chains: say A, and you should be raising B at the same time |
| `stack.md` | Choice cards: situation → recommendation → why → when it does not apply → what can still be reversed |
| `domains/ui.md` | UI frameworks, component libraries, system interfaces |
| `domains/platform.md` | Platform / operating system / device products |
| `domains/ecosystem.md` | Apps and plugin ecosystems |
| `domains/ai-agent.md` | AI assistants and agents |
| `domains/materials.md` | Outward-facing material (investors / customers) |
| (the profile itself) | Not in this directory: `product/requirements/requester-profile.md` (**seed**: the template ships an empty skeleton, the content belongs to the project and **never flows back**) |

## How to answer (for every seat)

1. **Read the profile first**; an empty profile means a new user — answer in "plain-language mode" (below).
2. **Give a plan card, not a pile of options**: recommended approach · why · cost · when it does not apply · what can still be reversed.
3. **Plain-language mode**: when the profile is empty, or he says "I am not technical", spell out each option's consequence in one plain sentence ("pick this and adding an English UI later means going through every page"), and mark the recommendation "pick this if you are unsure".
4. **Decide the technical and architectural things yourself** and write down what can be reversed; **commercial trade-offs, names, open or closed source, scope and schedule, and how it is described publicly** are always asked, with no default.
5. **Push along `chains.md` on purpose** — two or three items at most, each with its upside and cost.
6. **Ask before you build**; his own words go into the requirements inbox, **a ruling is appended to the profile** (with the date and the source), and anything important becomes an AD.
