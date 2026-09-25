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
# [BUGS_DIR knob] Reverse assertions are made on a **copy**, never on live bug files (project memory
# 11 and 13: the last time errors were staged in a live mailbox, two real letters were deleted).
D="${BUGS_DIR:-ai/bugs}"
# 🔴 **On hold (⏸): tell "waiting on an external condition" apart from "nobody retested"**
# (raised by the Reviewer seat 2026-09-23, after it bit us). The old test was "any `fixed, awaiting
# retest` goes red". What it protects is right -- **something fixed may not sit unretested** -- but
# real-machine bugs wait on "actually install from the disk once" or "the Requester plugs in a second
# cable": **external conditions the Reviewer cannot produce**. So that red became permanent, and
# **a permanent red is no red at all**: nobody reads it any more, and the real breaks hide behind it.
# New test: a `fixed, awaiting retest` that fills in **both** `Blocked on:` and `Cleared by:` is **not
# counted as a break, but is listed on its own**; 🔴 **on hold is not an archive** -- more than
# $BLOCKED_MAX days without movement goes red anyway (the Reviewer proposed this guard against it
# turning into a new dumping ground). "Without movement" is judged by **the last git commit time**
# (same test as 3c: mtime is reset by a single clone).
BLOCKED_MAX="${BUG_BLOCKED_MAX_DAYS:-21}"
days_since() {  # days from this file's last git commit until today; never committed counts as 0
  local iso ts now
  iso=$(git -C "$ROOT" log -1 --format=%cI -- "$1" 2>/dev/null)
  [ -n "$iso" ] || { echo 0; return; }
  ts=$(date -d "$iso" +%s 2>/dev/null) || { echo 0; return; }
  now=$(date +%s); echo $(( (now - ts) / 86400 ))
}
fld() {  # fld <file> <field>: read one header line; "--" and "none" count as empty
  local v; v=$(grep -m1 "^$2:" "$1" | sed "s/^$2:[[:space:]]*//; s/[[:space:]]*#.*//; s/[[:space:]]*$//")
  case "$v" in —|-|--|none|None|N/A) v="";; esac; printf '%s' "$v"
}
held=0
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
  blk="$(fld "$f" "blocked on")"; who="$(fld "$f" "cleared by")"
  if [ "$st" = "fixed, awaiting retest" ]; then
    if [ -n "$blk" ] && [ -n "$who" ]; then
      held=$((held+1)); d="$(days_since "$f")"
      if [ "$d" -gt "$BLOCKED_MAX" ]; then
        echo "  x  $f -- on hold for $d days with no movement (limit $BLOCKED_MAX): waiting on \"$blk\", cleared by $who."
        echo "     On hold is not an archive: retest once the condition arrives, chase the person who can produce it, or rule it will not be fixed and say why."
        bad=$((bad+1))
      else
        echo "  ⏸  $f -- on hold $d days: waiting on \"$blk\" (cleared by: $who) -- an external condition, not counted as a break."
      fi
    elif [ -n "$blk" ] || [ -n "$who" ]; then
      echo "  x  $f -- putting it on hold takes both lines: blocked on = which external condition, cleared by = who can produce it."
      echo "     Half a hold has no owner, so nobody knows who to chase -- which is exactly how it rots there."
      bad=$((bad+1))
    else
      echo "  ~  $f -- status \"fixed, awaiting retest\": development says it is fixed, **the Reviewer seat has not retested**."
      echo "     The retest does not hang on a command word; do it this round (ai/bugs/README.md)."
      echo "     If it really is waiting on an external condition (a real machine, hardware, the Requester), add the \"blocked on:\" and \"cleared by:\" lines."
      bad=$((bad+1))
    fi
  elif [ -n "$blk" ]; then
    echo "  x  $f (status $st) -- only \"fixed, awaiting retest\" may be put on hold."
    echo "     Writing \"blocked on:\" in another status is granting yourself an exemption: to fix means not fixed yet, to reproduce means not reproduced yet."
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
  echo "BUGS-FAIL ($bad breaks; ⏸ $held more on hold on external conditions, not counted)"
  exit 1
fi
echo "BUGS-OK ($(echo "$files" | wc -l) bugs, loop intact; ⏸ $held on hold waiting on external conditions)"
