#!/usr/bin/env bash
# check-bugs: is the bug loop broken somewhere in the middle?
# Usage: bash ops/verify/check-bugs.sh
# Exit 0 = loop intact; 1 = there are breaks (listed); 2 = wrong structure.
#
# It judges the thing being protected, not its textual shadow:
#   (1) A bug that can go to development must actually have reproduction steps --
#       the criterion is **numbered lines under "Steps"**, not "the word Steps appears in the file".
#   (2) A fixed-but-not-retested bug may not sit overnight -- status `fixed, awaiting retest` goes red.
#   (3) Development may not close bugs -- a `closed` one must have a non-empty "Retest" section.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
D="ai/bugs"
[ -d "$D" ] || { echo "cannot find $D"; exit 2; }

bad=0
# The three rules "the three localization subheadings / the workaround / the pre-assertion" were added on 2026-09-15.
# Per ai/rules/workflow.md 3c, "no retroactive effect": **they only bite for bugs opened after that day**,
# and older files only get a note, never a red mark -- development cannot write against a template that did not exist yet.
SINCE="${BUGRULES_SINCE:-2026-09-16}"
newer() {   # $1=the file; opened on or after SINCE returns 0
  local d; d=$(grep -m1 '^found:' "$1" | sed 's/^found:[[:space:]]*//;s/[[:space:]]*$//')
  [ -z "$d" ] && return 0
  [ "$d" \> "$SINCE" ] || [ "$d" = "$SINCE" ]
}
note(){ echo "  .  $* (an older file; no retroactive effect, per 3c)"; }

files=$(find "$D" -maxdepth 2 -name 'B-*.md' | LC_ALL=C sort)

if [ -z "$files" ]; then
  echo "BUGS-OK (no bug files yet -- the ledger is empty, not broken)"
  exit 0
fi

for f in $files; do
  st=$(grep -m1 '^status:' "$f" | sed 's/^status:[[:space:]]*//; s/[[:space:]]*#.*//; s/[[:space:]]*$//')
  case "$st" in
    reproduced|"to fix"|"fixed, awaiting retest"|closed)
      steps=$(sed -n '/^-[[:space:]]*\*\*Steps\*\*/,/^-[[:space:]]*\*\*Symptom\*\*/p' "$f" \
              | grep -cE '(^|[[:space:]])[0-9]+\.[[:space:]]*[^[:space:]]')
      if [ "$steps" -lt 1 ]; then
        echo "  x  $f (status $st) -- \"Steps\" has not one numbered step."
        echo "     Development cannot reproduce it, so it will fix a different problem."
        bad=$((bad+1))
      fi
      ;;
  esac
  if [ "$st" = "fixed, awaiting retest" ]; then
    echo "  ~  $f -- status \"fixed, awaiting retest\": development says it is fixed, **the Reviewer seat has not retested**."
    echo "     The retest does not hang on a command word; do it this round (ai/rules/workflow.md 3b)."
    bad=$((bad+1))
  fi
  # (4) the three "Localization" subheadings (required only from status reproduced onward) -- raised by the Supervisor seat's audit
  case "$st" in
    reproduced|"to fix"|"fixed, awaiting retest"|closed)
      for h in "Can it be reproduced locally" "Elimination tree" "Conclusion or current hypothesis"; do
        grep -qE "^###[[:space:]]*$h" "$f" || {
          if newer "$f"; then
            echo "  x  $f (status $st) -- the \"Localization\" section is missing the subheading \"$h\" (ai/bugs/README.md)"
            bad=$((bad+1))
          else note "$f is missing \"$h\""; fi; }
      done
      ;;
  esac
  # (5) a workaround may only sit inside "Mitigation"
  if grep -qE 'work.?around|incognito|another window' "$f"; then
    grep -qE '^##[[:space:]]*Mitigation' "$f" || {
      if newer "$f"; then
        echo "  x  $f -- it writes down a workaround, but has no \"## Mitigation\" section."
        echo "     A workaround answers \"how do we get by for now\", not \"why does this happen\" -- it is not a delivery."
        bad=$((bad+1))
      else note "$f workaround not under \"Mitigation\""; fi; }
  fi
  # (6) "did not reproduce" only counts as a conclusion when the pre-assertions are all green
  if grep -qE 'not reproduced|did not reproduce|could not reproduce' "$f"; then
    grep -q 'pre-assertion' "$f" || {
      if newer "$f"; then
        echo "  x  $f -- it says \"did not reproduce\", but there is no \"pre-assertion\"."
        echo "     A \"did not reproduce\" with no pre-assertion is only \"my rig never came up\"."
        bad=$((bad+1))
      else note "$f \"did not reproduce\" with no pre-assertion"; fi; }
  fi
  if [ "$st" = "closed" ]; then
    body=$(sed -n '/^##[[:space:]]*Retest/,$p' "$f" | tail -n +2 | grep -cE '[^[:space:]]')
    if [ "$body" -lt 1 ]; then
      echo "  x  $f -- marked \"closed\", but the \"Retest\" section is empty."
      echo "     Closing is the Reviewer seat's call, and it must say how it was verified."
      bad=$((bad+1))
    fi
  fi
done

if [ "$bad" -gt 0 ]; then
  echo
  echo "BUGS-FAIL ($bad breaks)"
  exit 1
fi
echo "BUGS-OK ($(echo "$files" | wc -l) bugs, loop intact)"
