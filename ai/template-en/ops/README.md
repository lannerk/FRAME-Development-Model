# ops/ — deployment and ops

| Subdirectory | What goes in |
|---|---|
| `machines.json` | **The test machine list — the one and only source of machine details in the whole project** (see below) |
| `paths.ps1` | **In-repo paths are defined here once**, and every `.ps1` dot-sources it at the top (see `docs/ops/realmachine.md` §4) |
| `scripts/` | The **real implementation** of the deployment and ops scripts |
| `verify/` | Guard scripts: `check-paths.sh` (hard-coded IPs and old directory names) · `check-inbox.sh` (anything missed in the inbox) · `check-bugs.sh` (bug loops left open) · `check-entrypoints.sh` (whether the alias entry points are still just pointers) · `frame-scan.sh` (tells what is what at initialization) · `check-template-sync.sh` (whether the template kept up) |
| `units/` | Service units (systemd and the like) |

**The commonly used scripts keep a thin shell at the repo root** (ten-odd lines that only forward to the implementation in `ops/scripts/`),
so the Requester can run them straight from the repo root without remembering a deep path.
**The thin shell is not allowed to grow logic** — once it has logic, it is a second source of truth again.

**What does not go here**: self-check scripts that travel with the source (those live in `src/<project>/tools/`, next to the code they scan);
binaries and upgrade packages (those go in `dist/`, not committed).

---

## When a round is called: **the Reviewer seat commits locally; the Requester pushes**

**Whoever made the change commits it — not just the Reviewer seat**:

| Who | When to commit |
|---|---|
| **Reviewer seat** | After a review round ends and the verdict is given |
| **Maintainer seat** | **After changing the rules** (rules, role handbooks, `CLAUDE.md`, guard scripts, both templates, the maintenance log). The title says which rule changed |
| Developer seat | **Does not commit.** Its changes go in with the Reviewer seat's round — **committing your own work is bypassing the review** |

**Run it once**:

```
bash ops/scripts/commit-round.sh "<one-line title>"      # want to see what the commit message looks like first: add --dry
```

It only does **`add` + `commit`**, and **never pushes**. Pushing is the Requester's business.

### 🔴 SourceTree is open on this machine, so there are five things you may not do

| Not allowed | Why |
|---|---|
| **No push** | Whether to push, and to which remote, is the Requester's decision |
| **No amend / rebase / reset / cherry-pick / force** | Those **rewrite history**. SourceTree has this repo open, and a rewritten history shows up there as a tangle that has to be restored by hand |
| **No touching `git config`** | `core.autocrlf` and the like are the Requester's Windows-side settings; touch them and the screen fills with fake diffs |
| **No creating or switching branches** | Commit on the current branch; switch and the Requester will not find his own changes in SourceTree |
| **No deleting `.git/index.lock`** | That lock means **some git is working** (most likely SourceTree). Grabbing it makes it error out on the spot. On hitting the lock the script exits as-is |

**A red guard blocks the commit.** "Red means not done" — committing red writes "not done" into history,
and the next person to clone it still thinks this is a clean baseline. If you really must commit red (say this round is the fix for it):
`ANYWAY=1 bash ops/scripts/commit-round.sh "<title>"`, and **the commit message will say it went in red**.

**Who the commit is by**: this machine has no global git identity (the Requester's identity is in his Windows-side global config, invisible from here).
The script **takes it from the author of the last commit** and passes it in temporarily with `-c` — **it does not write it into `.git/config`** (that would override his global identity).
The commit message ends with a `Co-Authored-By: Claude` line, **making clear this one is AI-generated**.

The script checks four things itself first, and if any one of them fails it **exits as-is and touches nothing**:
`index.lock` present / an unfinished merge, rebase or cherry-pick / HEAD detached / nothing to commit.

> **`-c core.fileMode=false`**: the script runs off a mounted drive, and the executable bit the Linux side sees differs from the Windows side.
> Leave it on and a pile of `mode change 100644 → 100755` goes into the commit — pure noise, and it turns SourceTree's diff red from top to bottom.

### What goes into the commit message

The title + the date + the scope of the change (`--shortstat`) + **the `T-####` / `B-####` / `AD###` this round touched** + **a one-line guard summary**,
ending with "not pushed, confirm in SourceTree and push". The ids are **scraped out of the changed file names and the diff, not typed in by a human** —
a human misses some, a scrape does not.

## What you changed on the real machine must get back into the repo: **if it will not write, park it**

**The repo is the only source; the real machine is a volatile live network.** Change the real machine and not the repo, and next stage
someone starting from the repo overwrites it back — **and neither side reports an error**. This is the hardest kind to track down.

- **Developer seat**: once the real machine is changed, **write back the same round**, reconciling each file with `sha256sum -c`. **No reconciliation = no write-back.**
- The write-back is refused (held on Windows): work through the four-step ladder in `docs/ops/realmachine.md`, and **do not keep retrying the same trick**.
- **None of the four works → park it**: put those files in `tmp/writeback-pending/` (keeping their original relative paths),
  and state in the report **which file, why it did not get in, and how it has to be merged**.
- **Guard**: `bash ops/verify/check-writeback.sh` — that directory being non-empty is red.
  **Parked is not delivered**, and the Reviewer seat **may not pass it** while that is red.
- **The Reviewer seat does not merge feature code for him** (reviewing what you wrote yourself is not a review). What it can do: name this one in the verdict,
  if necessary get the Requester to close the program holding the file on the Windows side, **and then reject it so development merges it himself**.

## `conformance sweep`: when the Requester thinks things have drifted

The Requester says one line, **`conformance sweep`**, the Maintainer seat runs one command, and **answers with one table only**:

```
bash ops/verify/check-all.sh          # all green is one line; for the red ones, -v for the detail
```

**Run the scripts before reading the files.** Everything a machine can judge (broken links, hardcoded IPs, the inbox, the bug loop,
ledger fields and the state double write, the line budget, entry files, parked write-backs, template sync) runs in one go,
and **only the red ones are worth a human's time** — reading the output of eight scripts into context one line at a time is pure token burn.

Only what a machine cannot judge (whether a rule itself makes sense, whether it contradicts another, whether one should be added) is a human's turn,
and then **read the maintenance log first** to see where the last change got to, instead of paging from the top.
