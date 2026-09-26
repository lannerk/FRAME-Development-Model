#!/usr/bin/env bash
# check-mirror: the source and the prototype mirror may not drift apart.
# Usage: bash ops/verify/check-mirror.sh
#        bash ops/verify/check-mirror.sh --accept   record today's differences as the baseline (**shrink only**)
# Exit codes: 0 = no new drift; 1 = new drift, or the baseline should be narrowed; 2 = wrong structure.
#
# [Why this exists] Some projects keep a **prototype mirror** of the front end (the copy the Requester
# looks at), with a rule saying "change the front end and copy the mirror in the same round" -- and rules
# like that typically have **no script checking them from the day they were written**. Measured once:
# three files had already drifted on HEAD, one of them by nearly nine hundred lines, while every guard
# was green. **A rule with no guard is not a rule** — that is this method's own criterion.
#
# [What is actually tested] That **the mirror matches the source content for content**, not "did someone
# remember to copy". Only files that **already exist in the mirror** are tested: whether a new file
# belongs in the prototype is a human judgement, not a guard's.
#
# [What about the backlog] "A red nobody can fix is noise." So there is a baseline,
# `ops/verify/.mirror-baseline`: the files in it **may differ**, but the list **may only shrink** --
# once a file is aligned, the guard tells you to delete its line (shrink only, no going back).
# Clearing the backlog belongs to the seat that owns the prototype, not to the guard.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
# 🔴 **A project-specific path may never be hard-coded into FRAME** (the Requester ruled on 2026-09-26:
# "frame should also be independent of any specific project"): the values come from
# `ops/verify/paths.env` (one `KEY=value` per line, class seed: the template ships only commented
# samples), and an environment variable can override them. **Unconfigured means skip, with a line saying
# how to configure it** -- never red: a red from a test that does not apply gives every new project a
# false red on day one, and the only cure for a false red is learning to ignore it.
[ -f ops/verify/paths.env ] && . ops/verify/paths.env
SRC="${MIRROR_SRC:-}"
DST="${MIRROR_DST:-}"
BASE="${MIRROR_BASE:-ops/verify/.mirror-baseline}"
if [ -z "$SRC" ] || [ -z "$DST" ] || [ ! -d "$SRC" ] || [ ! -d "$DST" ]; then
  echo "MIRROR-SKIP (no mirror pair configured -- set MIRROR_SRC= and MIRROR_DST= in ops/verify/paths.env, or pass them as environment variables)"; exit 0
fi
bad=0; drift=""

while IFS= read -r b; do
  n=$(basename "$b")
  a="$SRC/$n"
  [ -f "$a" ] || continue                     # in the mirror but not in the source: the prototype's own, not tested
  # [Do not test line endings] A Windows checkout turns one side into CRLF, and **a byte-for-byte
  # comparison then reports "only the line endings differ" as drift** (the first run caught three such
  # files: same line count, same content, only CR). The test is content, not bytes -- strip CR first.
  diff -q <(tr -d '\r' < "$a") <(tr -d '\r' < "$b") >/dev/null 2>&1 && continue
  drift="$drift$n
"
done < <(find "$DST" -maxdepth 1 -type f \( -name '*.js' -o -name '*.html' -o -name '*.css' \) | LC_ALL=C sort)
drift=$(printf '%s' "$drift" | grep . || true)

if [ "${1:-}" = "--accept" ]; then
  printf '%s\n' "$drift" | grep . > "$BASE" || : > "$BASE"
  echo "baseline recorded in $BASE ($(grep -c . "$BASE" 2>/dev/null || echo 0) files allowed to differ)"
  echo "⚠ The baseline **may only shrink**: align one file and delete its line. It is not a switch for silencing the check."
  exit 0
fi

allowed() { [ -f "$BASE" ] && grep -qxF -- "$1" "$BASE"; }

while IFS= read -r n; do
  [ -n "$n" ] || continue
  la=$(wc -l < "$SRC/$n"); lb=$(wc -l < "$DST/$n")
  if allowed "$n"; then
    echo "  .  $n is still in the baseline (source $la lines / mirror $lb) -- backlog, for the owning seat to align"
  else
    echo "  x  the mirror drifted: $n (source $la lines / mirror $lb) -- change the front end, mirror it the same round"
    bad=$((bad+1))
  fi
done <<< "$drift"

if [ -f "$BASE" ]; then
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if [ -f "$SRC/$n" ] && [ -f "$DST/$n" ] && diff -q <(tr -d '\r' < "$SRC/$n") <(tr -d '\r' < "$DST/$n") >/dev/null 2>&1; then
      echo "  x  $n is aligned now but still listed in the baseline $BASE -- delete that line (the baseline may only shrink)"; bad=$((bad+1))
    fi
  done < "$BASE"
fi

if [ "$bad" -gt 0 ]; then
  echo
  echo "MIRROR-FAIL ($bad)"
  echo "  The rule: change $SRC and mirror it into $DST in the same round. The backlog is in $BASE, **shrink only**."
  exit 1
fi
echo "MIRROR-OK (the mirror matches the source; $(grep -c . "$BASE" 2>/dev/null || echo 0) backlog files await the owning seat)"
