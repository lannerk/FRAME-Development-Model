# Maintenance log

> **Maintainer only.** Every single thing the Requester says to the Maintainer goes into this table **once confirmed**, one line each.
>
> **This is not the inbox.** The inbox (`product/requirements/inbox.md`) is the requirement channel "Requester → Reviewer";
> this one is the **model-maintenance** channel "Requester → Maintainer". **What is said to the Maintainer is not a requirement** —
> if he wants to raise a feature requirement or report a bug, he goes to the Reviewer.
>
> **Append only, never delete a row.** When it is handled, change "status"; don't delete the row.

## Rules

1. **Record it only after it is confirmed.** Still under discussion and undecided: don't record it. Decided: **record it the same round**.
2. **Verbatim quote, word for word**, no paraphrase — paraphrase loses the purpose and leaves only the surface action.
3. Every entry states: **what changed, why, how it was verified**.
4. **The "which seats it affects" column is a mandatory four-slot answer**: `dev✓ rev✓ sup— mnt✗` (✓ would commit it / ✗ would not / — not applicable).
   **A verdict of "it only affects one seat" must state why the other three would not** — cannot state it and the four-seat cross-check was not done (`ai/roles/maintainer.md` §3b).
5. **Changing the rules = changing two places**: what changed in this project, and `ai/template/` follows the same round (the ⛔ at the top of `ai/roles/maintainer.md`).
6. Run the guards at wrap-up; **maintenance is not done while `check-template-sync.sh` is red**, and that entry may not be marked "done".
7. **When you report you must say explicitly that both templates, Chinese and English, are in sync** — he should not have to ask you back (the ⛔ at the top of `ai/roles/maintainer.md`).

> **Rules 5 and 6 only count for "the repo that owns the template"** (the one with `ai/template/` in its root).
> **If this project was copied out of the template, that script does not exist here at all, so skip both** —
> changing a rule and recording one entry is the whole of it (the ⛔ at the top of `ai/roles/maintainer.md`).

## Status

| status | meaning |
|---|---|
| `in progress` | Confirmed, being changed |
| `done` | Changed and verified; the verification output goes in "how it was verified" |
| `reverted` | Changed and then rolled back; state why |

---

| # | Date | Requester's exact words (verbatim quote) | What changed | How it was verified | Which seats it affects | **Template sync** | Status |
|---|---|---|---|---|---|---|---|
| | | | | | | | |
