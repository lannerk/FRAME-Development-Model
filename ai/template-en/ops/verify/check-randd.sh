#!/usr/bin/env bash
# check-randd: whether the R&D line (ai/RandD/) still has its structure and its indexes.
# Usage: bash ops/verify/check-randd.sh
#        RANDD_DIR=/tmp/rdtest bash ops/verify/check-randd.sh   <- run reverse assertions against a COPY
# Exit codes: 0 = clean, or not applicable; 1 = something is wrong; 2 = the structure is wrong.
#
# [Why this exists] The R&D line's north star is "at graduation the whole process can be reconstructed"
# (ai/RandD/README.md). Whether it can be is not decided by whether things were written down, but by
# **whether there are indexes, whether the live files went out of control, and whether graduation really
# self-checked**. All three are machine-testable, and **leaving them to memory is leaving them undone**.
#
# [What is actually tested]
#   (1) A topic directory is either complete or it is not a topic directory -- **half a skeleton is worse
#      than none** (the next person assumes it is there);
#   (2) `log/ lab/ runs/ notes/` each need an `INDEX.md`: **an archive with no index does not exist three
#      months later**;
#   (3) A topic must have a line in `index.md`: **a topic nobody can find does not exist**;
#   (4) The live files (00-status 200 / 01-open-questions 100 / the topic card 50) and the line's memory (80)
#      may not exceed their caps -- the dead ones (log/lab/runs/notes/the ideas book) have **no cap at all**:
#      they control cost by **not being read routinely**, not by deleting content;
#   (5) 🔴 Anything marked graduated must have `graduation/04-criteria-selfcheck.md` with **all nine green** --
#      without this test, "graduate now, fill the gaps later" is certain to happen, and that bill explodes
#      mid-development at ten times the price.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
D="${RANDD_DIR:-ai/RandD}"

# [New projects] No such line means skip, not an error -- whether the R&D line is opened is the Requester's call.
[ -d "$D" ] || { echo "RANDD-SKIP (no $D; this project has not opened an R&D line)"; exit 0; }

bad=0; topics=0
IDX="$D/index.md"
[ -f "$IDX" ] || { echo "  x  missing $IDX -- the topic list is the only way in to any topic"; bad=$((bad+1)); }
[ -f "$D/README.md" ] || { echo "  x  missing $D/README.md -- the directory and numbering rules have no source"; bad=$((bad+1)); }

# The line's memory: same format as ai/memory.md, capped at 80 lines (the budget table in ai/rules/layout.md §3 is the
# single source; this only checks existence and the line count)
if [ -f "$D/memory.md" ]; then
  n=$(wc -l < "$D/memory.md")
  [ "$n" -gt 80 ] && { echo "  x  $D/memory.md  $n lines / cap 80 -- move whole blocks into the topic notes/ and leave one pointer line"; bad=$((bad+1)); }
fi

for t in "$D"/*/; do
  [ -d "$t" ] || continue
  b=$(basename "$t")
  # 🔴 `NN-topic` is the **placeholder skeleton shipped with the template**, not a real topic: in a new project it
  #    would be reported as "not listed in index.md", so every new project starts with one red that the template
  #    itself caused (measured during the first distribution).
  case "$b" in archive|drafts|NN-topic) continue;; esac
  topics=$((topics+1))

  # (1) the skeleton is complete
  # 🔴 **Match on the `00-` `01-` `02-` prefix, not on the file name**: the second half of the name follows
  # the project's language (00-status.md here, 00-现状.md in a Chinese project) -- **the prefix is the stable half**.
  # What must hold is that those three things exist, not that they are called something in particular.
  for f in README.md decisions.md tasks/index.md; do
    [ -f "$t$f" ] || { echo "  x  $t is missing $f -- the topic skeleton is incomplete (half a skeleton is worse than none)"; bad=$((bad+1)); }
  done
  for pre in 00 01 02; do
    ls "$t$pre"-*.md >/dev/null 2>&1 || { echo "  x  $t is missing $pre-*.md (status / open questions / ideas; the name follows your language, the prefix does not)"; bad=$((bad+1)); }
  done
  # (2) each of the four archive directories needs an INDEX.md (if the directory is there, the index must be too)
  for d in log lab runs notes; do
    [ -d "$t$d" ] || continue
    [ -f "$t$d/INDEX.md" ] || { echo "  x  $t$d/ has no INDEX.md -- an archive without an index does not exist three months later"; bad=$((bad+1)); }
  done
  # (3) index.md must carry a line for this topic
  if [ -f "$IDX" ]; then
    num=${b%%-*}
    grep -qF -- "$b" "$IDX" || grep -qE "^\| *\`?$num\`? *\|" "$IDX" \
      || { echo "  x  $b is not listed in $IDX -- a topic nobody can find is a topic that is not there"; bad=$((bad+1)); }
  fi
  # (4) the live files' line counts (the dead ones have no cap)
  for pair in "00:200" "01:100"; do
    pre="${pair%%:*}"; cap="${pair##*:}"
    for f in "$t$pre"-*.md; do
      [ -f "$f" ] || continue
      n=$(wc -l < "$f")
      [ "$n" -gt "$cap" ] && { echo "  x  $f  $n lines / cap $cap (only the live files have a cap; log/ lab/ runs/ notes/ and the ideas book do not)"; bad=$((bad+1)); }
    done
  done
  if [ -f "$t"README.md ]; then
    n=$(wc -l < "$t"README.md)
    [ "$n" -gt 50 ] && { echo "  x  $t""README.md  $n lines / cap 50 (the topic card holds what/criteria/status only; the process lives in log/)"; bad=$((bad+1)); }
  fi
  # (5) marked graduated means there must be a nine-green self-check
  if [ -f "$IDX" ] && grep -F -- "$b" "$IDX" | grep -qE "graduated|已毕业"; then
    sc=$(ls "$t"graduation/04-*.md 2>/dev/null | head -1)
    if [ -z "$sc" ]; then
      echo "  x  $b is marked graduated in $IDX, but graduation/ has no 04-* self-check -- nine criteria unchecked is not graduation"; bad=$((bad+1))
    else
      green=$(grep -cE '✅|all green|pass' "$sc" || true)
      [ "$green" -ge 9 ] || { echo "  x  $sc shows only $green green items / 9 required -- no graduating first and filling the gaps later"; bad=$((bad+1)); }
    fi
  fi
done

if [ "$bad" -gt 0 ]; then
  echo "RANDD-FAIL ($bad)"
  echo "  The rules are in $D/README.md: one directory per topic; an INDEX.md in each archive dir; caps on the live files; nine green criteria before graduation."
  exit 1
fi
echo "RANDD-OK ($topics topics: skeletons complete, indexes present, live files within their caps, graduations self-checked)"
