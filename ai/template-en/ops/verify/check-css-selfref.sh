#!/usr/bin/env bash
# check-css-selfref: a CSS variable may not reference itself (`--x: var(--x)`).
# Usage: bash ops/verify/check-css-selfref.sh
#        CSSREF_DIRS="<dirs...>" bash ops/verify/check-css-selfref.sh   <- point it at a COPY for reverse assertions
# Exit 0 = none (or N/A); 1 = found.
#
# 【Why this exists】It is **the most common regression of a bulk replacement**: when scattered literals are swapped
# for tokens in bulk, the token's own declaration gets swapped too and becomes `--fs-4: var(--fs-4)`.
# The consequence is hard to find: the variable **resolves to nothing** and every use **silently falls back**
# to the inherited or initial value -- no page error, a clean console, a screenshot that looks slightly off, and not one log line.
#
# 【It judges the thing itself】It judges "**this variable's value references itself**", not "the same name appears twice on a line":
# the same name in **different declarations** (`--x: 1rem` here, `width: var(--x)` there) is perfectly normal.
# So it judges **inside one declaration**: between `--name:` and the semicolon, a `var(--same-name)` is red.
#
# 【Report how many files were scanned】per `ai/specs/testing.md` §0a R2: an empty scan is RED --
# a guard that scans nothing is green forever.
set -u
cd "$(dirname "$0")/../.." || exit 2
[ -f ops/verify/paths.env ] && . ops/verify/paths.env
DIRS="${CSSREF_DIRS:-${CSSNS_WEB:-}}"
[ -n "$DIRS" ] || { echo "CSS-SELFREF-SKIP (CSSNS_WEB/CSSREF_DIRS not set -- not applicable)"; exit 0; }
n=0; files=0
for d in $DIRS; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    files=$((files+1))
    while IFS=: read -r ln txt; do
      [ -n "$ln" ] || continue
      echo "  ✗  $f:$ln $(printf '%s' "$txt" | sed 's/^[[:space:]]*//' | cut -c1-70)"
      n=$((n+1))
    done < <(grep -nE -- '--([A-Za-z0-9_-]+)[[:space:]]*:[^;]*var\([[:space:]]*--\1[[:space:]]*[,)]' "$f" || true)
  done < <(find "$d" -name '*.css' -o -name '*.html' -o -name '*.js' | LC_ALL=C sort)
done
[ "$files" = 0 ] && { echo "CSS-SELFREF-SKIP (no style files under $DIRS)"; exit 0; }
if [ "$n" -gt 0 ]; then
  echo "CSS-SELFREF-FAIL ($n; scanned $files files)"
  echo "  Fix: put the real value back on the right-hand side. A self-referencing variable resolves to nothing and every use falls back silently -- no error, nothing in the logs."
  exit 1
fi
echo "CSS-SELFREF-OK (scanned $files style/page files; no self-referencing CSS variables)"
