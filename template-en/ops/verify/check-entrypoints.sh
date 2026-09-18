#!/usr/bin/env bash
# check-entrypoints: have other platforms' entry files turned into a second source of truth?
# Usage: bash ops/verify/check-entrypoints.sh
# Exit 0 = they are all still pointers; 1 = an entry file grew or points nowhere; 2 = wrong structure.
#
# Why this guard: different platforms auto-load different entry files (CLAUDE.md / AGENTS.md / GEMINI.md ...).
# The lazy move is to copy CLAUDE.md -- and once two entry documents exist side by side they **drift apart with no symptom at all**:
# someone edits one, the other still gets auto-loaded, and nobody finds out until a session has worked to an outdated rule.
# So the rule is: **CLAUDE.md is the only real entry point; every other one holds a pointer and nothing else.** This guard judges exactly that.
#
# It judges the thing being protected: **has a rule been stuffed into an alias file** --
# the criterion is short enough + actually points at CLAUDE.md, not whether some keyword appears.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2

MAX_LINES=25          # a pointer plus a paragraph of rationale is plenty; beyond that it is copying content
bad=0

[ -f CLAUDE.md ] || { echo "  x  CLAUDE.md not found -- it is the real entry point, and the guards use it to locate the repo root."; exit 1; }

# Alias entry points: the files various platforms auto-load
for f in AGENTS.md AGENT.md GEMINI.md .github/copilot-instructions.md .cursorrules; do
  [ -f "$f" ] || continue
  n=$(wc -l < "$f")
  if [ "$n" -gt "$MAX_LINES" ]; then
    echo "  x  $f has $n lines (limit $MAX_LINES) -- it should be one pointer, not a second set of rules."
    echo "     Two entry points drift, and it shows no symptom. Keep the content in CLAUDE.md alone."
    bad=$((bad+1))
  fi
  if ! grep -q 'CLAUDE\.md' "$f"; then
    echo "  x  $f does not point at CLAUDE.md -- then where exactly does it send people?"
    bad=$((bad+1))
  fi
done

if [ "$bad" -gt 0 ]; then
  echo
  echo "ENTRYPOINTS-FAIL ($bad problems)"
  exit 1
fi
echo "ENTRYPOINTS-OK (CLAUDE.md is the only real entry point; the aliases are still pointers)"
