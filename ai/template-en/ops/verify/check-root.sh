#!/usr/bin/env bash
# check-root: whether anything outside the list has grown at the repo root, and whether the scratch area's naming rule is actually guarded.
# Usage: bash ops/verify/check-root.sh
# Exit codes: 0 = clean; 1 = an item outside the list, or a name that breaks the rule; 2 = the structure is wrong.
#
# [Why this exists] Measured by the Supervisor seat on 2026-09-16: **the old scratch-area name came back as a real directory
# and had already been committed**, and not one of the ten guards said a word. Every guard at the time only tested
# "does a script or doc mention the old name" -- **testing that someone mentions it, not that it exists**: testing a
# shadow again. In the same round it turned out a doc was teaching people to put thin `.ps1` shells at the repo root,
# in direct conflict with the top-level list in `layout.md` §1, and one project really did grow four of them.
# **Together the two say: the root directory never had a guard.**
#
# [Three tests]
#   (1) **Every entry at the repo root (files and directories) must be in the top-level table of
#      `ai/rules/layout.md` §1** -- that table is the single source of the criterion (the same rule as the budget and
#      ownership tables: never copy a second list into a script).
#   (2) **An old name may not exist as a real path** (not merely: do not write it in a script).
#   (3) **Every first-level entry under `claude-outputs/<seat>/` must start with `YYYY-MM-DD-`** (the naming rule in
#      `claude-outputs/README.md`, which used to live only in a doc with nothing enforcing it). Exemptions go in
#      `ops/verify/.rootcheck-allow`, one per line -- **an explicit exemption, never "be careful next time"**.
set -u
# 🔴 **A read-only git call must never create an index.lock** (root cause reported by the Supervisor
# 2026-09-24, hit twice for real): the local Cowork workspace has **no delete permission by default**,
# while `git status` / `git diff` refresh the index as a side effect and **can create `.git/index.lock`
# without being able to remove it** -- so one guard run leaves a deadlock in the Requester's repository
# and every later commit (including his own in SourceTree) is blocked. The test is **"leave no lock in
# someone else's repo"**, not "does the script run". `GIT_OPTIONAL_LOCKS=0` makes git skip those optional
# locks; a real `add`/`commit` still takes its own lock and is unaffected.
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
L="ai/rules/layout.md"
[ -f "$L" ] || { echo "cannot find $L (the top-level list lives there)"; exit 2; }
ALLOW="ops/verify/.rootcheck-allow"
bad=0
allowed() { [ -f "$ALLOW" ] && grep -qxF -- "$1" "$ALLOW"; }
# [Why git-ignored things are skipped] A tool (e.g. the Claude desktop app) may keep recreating a directory at the root;
# a guard that reports it red every time becomes "high false-alarm rate plus a one-key exemption" -- we already paid for
# that lesson once on template sync. So the criterion is **only what is in the repo counts**: what `.gitignore` blocks is
# not repo content (a tool's own output belongs to the tool), **but the moment someone commits it (it becomes tracked)
# it is no longer ignored and goes red again**. The thing being protected has not changed.
ignored() { git check-ignore -q -- "$1" 2>/dev/null; }
tracked() { git ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }
skip()    { tracked "$1" && return 1; ignored "$1"; }

# ---- (1) the root allowlist: read from the table in layout.md §1 ----
# A table row looks like: | `ai/` | what goes in | who writes | committed |   or   | `CLAUDE.md` | ... |
WL=$(awk '/^## 1\. Top level/{f=1} f && /^## 2\./{exit} f && /^\|/ {
      line=$0; sub(/^\|[[:space:]]*/, "", line); sub(/[[:space:]]*\|.*$/, "", line);
      gsub(/`/, "", line); gsub(/\*\*/, "", line);
      n=split(line, a, /[ ，、]/);
      for (i=1;i<=n;i++) { t=a[i]; sub(/\/$/, "", t); if (t ~ /^[A-Za-z0-9_.-]+$/) print t }
    }' "$L" | LC_ALL=C sort -u)
WL="$WL
.git
.gitignore"
for e in * .[!.]*; do
  [ -e "$e" ] || continue
  name="${e%/}"
  grep -qxF -- "$name" <<< "$WL" && continue
  allowed "$name" && continue
  skip "$name" && continue
  echo "  x  the repo root has an item that is not in the §1 list in $L: $e"
  echo "     either it does not belong here (move it), or the list should change (that is a rule change: Maintainer seat, and it goes into the maintenance log)"
  bad=$((bad+1))
done

# ---- (2) an old name may not exist as a real path ----
# [Division of labour with check-paths.sh] That one tests "a script or doc writes the old name"; this one tests "the old name really exists".
OLD='Claude outputs|SourceCode|_transfer|_to_delete'
while IFS= read -r p; do
  [ -n "$p" ] || continue
  allowed "$p" && continue
  skip "$p" && continue
  echo "  x  a legacy-structure name has come back as a real path in the repo: $p"; bad=$((bad+1))
done < <(find . -maxdepth 3 \( -path ./.git -o -path ./archive -o -path ./tmp -o -path ./dist \) -prune -o \
          -print 2>/dev/null | sed 's#^\./##' | grep -E "(^|/)($OLD)(/|$)" | LC_ALL=C sort -u)

# ---- (3) claude-outputs naming: a first-level entry must carry a date ----
# [No retroactivity] Per `ai/rules/workflow.md` §3c: a new criterion does not go back and fail older deliverables.
# The test is **when this entry entered the repository** (the commit time it was first added, not mtime -- a clone resets mtime).
SINCE="${ROOTRULES_SINCE:-2026-09-16}"
added_at() { git log --diff-filter=A --format=%cI -- "$1" 2>/dev/null | tail -1 | cut -c1-10; }
note(){ echo "  ·  $* (pre-existing, no retroactive effect per §3c)"; }
# [Only the four seats + shared may sit directly under claude-outputs] The table in `claude-outputs/README.md` is the list.
# Measured 2026-09-18: an extra top-level group had appeared (12 numbered chapters + a README) — **the content was fine,
# the position was not**: the scratch area is split by seat so that "who wrote it, who may change it" is answerable
# (nobody may touch the Supervisor seat's copy). Report **one** red, not one per file inside.
for e in claude-outputs/*; do
  [ -e "$e" ] || continue
  b=$(basename "$e")
  case "$b" in developer|reviewer|supervisor|maintainer|shared|README.md|index.md) continue;; esac
  allowed "$e" && continue
  skip "$e" && continue
  echo "  x  only the four seats + shared may sit directly under claude-outputs (see claude-outputs/README.md): found $e"
  echo "     move it under the seat that wrote it, or have the Maintainer seat change that table -- do not leave it somewhere nobody owns"
  bad=$((bad+1))
done

for d in claude-outputs/*/; do
  [ -d "$d" ] || continue
  case "$(basename "$d")" in developer|reviewer|supervisor|maintainer) ;; *) continue;; esac
  case "$d" in claude-outputs/shared/) continue;; esac   # shared/ holds a fixed set of subdirectories, looked at separately
  for e in "$d"*; do
    [ -e "$e" ] || continue
    b=$(basename "$e")
    case "$b" in README.md|index.md) continue;; esac
    allowed "$e" && continue
    printf '%s' "$b" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-' && continue
    # [Why a grouped directory with a README is allowed] The criterion judges "can it be found and explained",
    # not "does the name contain a date". A numbered chapter series is content in its own right, and forcing a date
    # prefix onto it would mean renaming a dozen files just to turn the guard green.
    # So: **a first-level entry that is a directory containing `README.md` counts as compliant**, and its files are not date-checked.
    [ -d "$e" ] && [ -f "$e/README.md" ] && continue
    a=$(added_at "$e")
    if [ -n "$a" ] && [ "$a" \< "$SINCE" ]; then note "$e has no date in its name (entered the repo $a)"; continue; fi
    echo "  x  scratch-area name breaks the rule (it must be <date>-<one line>): $e"; bad=$((bad+1))
  done
done

if [ "$bad" -gt 0 ]; then
  echo
  echo "ROOT-FAIL ($bad)"
  echo "  The single source for the top-level list is $L §1; exemptions go in $ALLOW, one per line (**explicit exemptions, never "we will be careful next time"**)."
  exit 1
fi
echo "ROOT-OK (nothing outside the list at the root, no legacy name revived, scratch-area names carry dates)"
