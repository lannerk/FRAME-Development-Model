#!/usr/bin/env bash
# check-budget: whether the line-count budgets are exceeded, and how many lines the **opening read** really is.
# Usage: bash ops/verify/check-budget.sh
# Exit codes: 0 = everything within budget; 1 = something is over; 2 = the structure is wrong.
#
# [Why this exists] The Supervisor seat's audit pointed out: all six guards were green at the time, while
# **at least 5 hard constraints written into the rules were being violated** at that same moment, including `CLAUDE.md`
# itself at 121 lines against a budget of 80 lines.
# The reason is simple: **the budget was written in a document and nothing was watching it**.
# Worse, it also found "the duties grew, so the limit went from 150 to 300" -- **the ruler gets quietly widened**.
#
# [How this guard keeps the ruler from moving quietly]
#   * The only source of the budget is the budget table in `ai/rules/layout.md`; this script **reads that table**
#     instead of keeping its own copy;
#   * to relax a limit you have to **change that table** -- a visible rule change, which by the rules goes into the maintenance log;
#   * the **total opening read** gets its own hard cap: that is the cost the budget is really there to govern.
#
# [It judges the thing being protected] It judges the **real line count** (`wc -l`), not "the number a document claims".
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
L="ai/rules/layout.md"
[ -f "$L" ] || { echo "cannot find $L (the budget table lives there)"; exit 2; }

# Hard cap on the total opening read: the most expensive of the four seats may not exceed it.
# **Relaxed from 600 to 660 on 2026-09-15**, reason recorded in ai/rules/maintenance-log.md:
# the opening read went from four files to five (the new ai/memory.md project memory, 80 lines).
# In the same round about 180 lines were already moved out of the role handbooks and workflow
# into "read on demand" files, so **these 60 lines were not saved by widening the ruler --
# a required file really was added**.
OPENING_CAP=660

bad=0

# ---- (1) file by file against the budget table ----
# A table row looks like: | `path` | 80 lines | what to do when over |
while IFS= read -r line; do
  f=$(sed -n 's/^|[[:space:]]*`\([^`]*\)`.*/\1/p' <<< "$line")
  n=$(sed -n 's/^|[^|]*|[^0-9]*\([0-9]\+\)[[:space:]]*lines.*/\1/p' <<< "$line")
  [ -z "$f" ] || [ -z "$n" ] && continue
  # Wildcard rows such as `T-*.md` are **expanded and checked one by one**; placeholders (<name>, ####) are skipped.
  # [Why this changed] The first version did an unconditional `continue` with a comment saying "handled separately"
  # while **no separate handling existed** -- so `ai/roles/*.md` was never checked at all, and `maintainer.md`
  # sat at 213 lines against a limit of 150 while the guard stayed green.
  # **A false green is more dangerous than no guard at all**; this one we walked into ourselves (project memory, type 4).
  case "$f" in
    *'<'*|*'####'*) continue;;
    *'*'*)
      for g in $f; do
        [ -e "$g" ] || continue
        a=$(wc -l < "$g")
        if [ "$a" -gt "$n" ]; then
          echo "  ✗  $g  actual $a lines / budget $n lines (over by $((a-n)))"; bad=$((bad+1))
        fi
      done
      continue;;
  esac
  [ -e "$f" ] || continue
  a=$(wc -l < "$f")
  if [ "$a" -gt "$n" ]; then
    echo "  ✗  $f  actual $a lines / budget $n lines (over by $((a-n)))"
    bad=$((bad+1))
  fi
done < <(grep -E '^\|[[:space:]]*`' "$L")

# ---- (2) the total opening read (this is the cost the budget is really about) ----
common=$(( $(wc -l < CLAUDE.md) + $(wc -l < ai/rules/laws.md) + $(wc -l < ai/state/now.md) + $(wc -l < ai/tasks/index.md) + $(wc -l < ai/memory.md) ))
worst=0; worst_role=""
for r in developer reviewer supervisor; do
  f="ai/roles/$r.md"; [ -e "$f" ] || continue
  t=$(( common + $(wc -l < "$f") ))
  # the first thing at the opening is checking the mail: count the three drop-boxes in that seat's own directory (<=15 lines each)
  for m in ai/mail/to-$r/from-*.md; do [ -e "$m" ] && t=$(( t + $(wc -l < "$m") )); done
  # the Supervisor seat by the rules **does not read the task queue** (the 🔴 in ai/roles/supervisor.md §1), so it is not counted for it
  [ "$r" = supervisor ] && t=$(( t - $(wc -l < ai/tasks/index.md) ))
  printf '  opening read · %-10s %4d lines\n' "$r" "$t"
  [ "$t" -gt "$worst" ] && { worst=$t; worst_role=$r; }
done
echo "  (= CLAUDE.md + laws.md + memory.md + now.md + tasks/index.md + that seat's handbook + mail/to-<seat>/ x3)"
if [ "$worst" -gt "$OPENING_CAP" ]; then
  echo "  ✗  the most expensive seat ($worst_role) $worst lines > hard cap $OPENING_CAP lines"
  echo "     Either move content into a \"read on demand\" file, or change the cap -- **changing the cap goes into the maintenance log**."
  bad=$((bad+1))
fi

if [ "$bad" -gt 0 ]; then
  echo; echo "BUDGET-FAIL ($bad over budget)"
  echo "  The only source of the budget is the table in $L. **Relaxing a limit = changing the rules**, and needs an entry in ai/rules/maintenance-log.md."
  exit 1
fi
echo "BUDGET-OK (every file within budget; the most expensive opening read is $worst lines / cap $OPENING_CAP)"
