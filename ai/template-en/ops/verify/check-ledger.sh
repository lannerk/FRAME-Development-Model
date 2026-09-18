#!/usr/bin/env bash
# check-ledger: does the ledger add up with itself -- fields, the double write, index vs entities, orphans.
# Usage: bash ops/verify/check-ledger.sh
# Exit codes: 0 = it adds up; 1 = something does not; 2 = the structure is wrong.
#
# [Why this exists] The Supervisor seat's audit pointed out: of the fields the task template requires,
# 28 out of 30 entries were missing some; "changing a state changes two places" was written as a rule
# and **nothing was watching it** (there happened to be 0 mismatches at that moment,
# but that came from discipline, not from a guard -- discipline gets tired).
#
# It judges four things, each of them the thing being protected itself, not its textual shadow:
#   (1) **whether the fields a task header should have are there** (it judges whether that line exists,
#       not whether those words appear somewhere in the file);
#   (2) **the state double write agrees**: the status in the task file header vs the status in that row of the index;
#   (3) **index and entities line up**: the files the index lists exist, and the files in the directory are in the index;
#   (4) **orphans**: there should be no loose files in the `ai/` root.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
bad=0
say(){ echo "  ✗  $*"; bad=$((bad+1)); }

# ---- (1) task fields ----
REQ="id|title|raised by|assigned to|status|priority|evidence|blocked on|opened|updated"
IFS='|' read -ra REQ_KEYS <<< "$REQ"
for f in ai/tasks/T-*.md; do
  [ -e "$f" ] || break
  hdr=$(sed -n '1,/^---$/p' "$f" | sed -n '2,$p')
  miss=""
  for k in "${REQ_KEYS[@]}"; do grep -qE "^$k:" <<< "$hdr" || miss="$miss \`$k\`"; done
  [ -n "$miss" ] && say "$f header is missing fields:$miss"
done

# ---- (2) the state double write agrees ----
IDX="ai/tasks/index.md"
if [ -f "$IDX" ]; then
  for f in ai/tasks/T-*.md; do
    [ -e "$f" ] || break
    id=$(grep -m1 '^id:' "$f" | sed 's/^id:[[:space:]]*//;s/[[:space:]]*$//')
    st=$(grep -m1 '^status:' "$f" | sed 's/^status:[[:space:]]*//;s/[[:space:]]*#.*//;s/[[:space:]]*$//')
    [ -z "$id" ] && continue
    row=$(grep -m1 -F "[$id]" "$IDX" || true)
    if [ -z "$row" ]; then say "$id has no matching row in $IDX (status changed in only one place?)"; continue; fi
    grep -qF "| $st |" <<< "$row" || \
      say "$id state double write disagrees: header = \"$st\", that index row says otherwise ($(cut -d'|' -f4 <<< "$row" | tr -d ' '))"
  done
fi

# ---- (2b) the bug state double write ----
# A hole the Supervisor seat measured: all four B file headers read `reproduced` while three rows in the index
# still read `to reproduce`, and check-bugs.sh **was green at that moment** -- it only looks at the B files, never reconciling them with the ledger.
# That table is exactly what gets read when the Requester asks "what bugs are left".
BIDX="ai/bugs/index.md"
if [ -f "$BIDX" ]; then
  for f in ai/bugs/B-*.md; do
    [ -e "$f" ] || break
    id=$(grep -m1 '^id:' "$f" | sed 's/^id:[[:space:]]*//;s/[[:space:]]*$//')
    st=$(grep -m1 '^status:' "$f" | sed 's/^status:[[:space:]]*//;s/[[:space:]]*#.*//;s/[[:space:]]*$//')
    [ -z "$id" ] && continue
    row=$(grep -m1 -F "$id" "$BIDX" || true)
    if [ -z "$row" ]; then say "$id has no matching row in $BIDX"; continue; fi
    grep -qF "| $st |" <<< "$row" || \
      say "$id state double write disagrees: header = \"$st\", that index row says \"$(echo "$row" | cut -d'|' -f6 | tr -d ' ')\""
  done
fi

# ---- (3) index vs entities ----
for pair in "ai/specs/index.md:ai/specs" "ai/bugs/index.md:ai/bugs"; do
  idx="${pair%%:*}"; dir="${pair##*:}"
  [ -f "$idx" ] || continue
  while IFS= read -r n; do
    [ -e "$dir/$n" ] || [ -e "$dir/archive/$n" ] || say "$idx lists $n, but it is in neither $dir/ nor $dir/archive/"
  done < <(grep -oE '^\|[[:space:]]*~*`[^`]+\.md`' "$idx" | sed 's/.*`\(.*\)`/\1/')
  while IFS= read -r p; do
    n=$(basename "$p"); case "$n" in index.md|README.md) continue;; esac
    grep -qF "\`$n\`" "$idx" || say "$dir/$n is not registered in $idx"
  done < <(find "$dir" -maxdepth 1 -name '*.md')
done

# ---- (3b) one ID may never have a second file ----
# [Why this exists] The Developer seat reported on 2026-09-15: **two ID collisions in one day, and this guard said OK both times**.
# The number is taken from `ai/tasks/index.md` ("next free task number"), but **nothing was checking whether that number was
# already in use** — two sessions taking a number at the same time each create a `T-0039-…`, the index records only one of them,
# and the other becomes **an orphan nobody can see**.
# What is being protected: one ID = one entity file (including `archive/`; renaming into the archive does not license a second one).
for pair in "ai/tasks:T" "ai/bugs:B" "ai/specs:AD"; do
  dir="${pair%%:*}"; pre="${pair##*:}"
  [ -d "$dir" ] || continue
  while IFS= read -r num; do
    [ -n "$num" ] || continue
    hits=$(find "$dir" -maxdepth 2 -name "$num-*.md" | LC_ALL=C sort | paste -sd' ' -)
    say "ID $num has more than one file (one ID, one entity): $hits"
  done < <(find "$dir" -maxdepth 2 -name "${pre}-[0-9][0-9][0-9][0-9]-*.md" \
            | sed -E "s#.*/(${pre}-[0-9]{4})-.*#\1#" | LC_ALL=C sort | uniq -d)
done

# ---- (4) loose files in the ai/ root ----
while IFS= read -r f; do
  case "$(basename "$f")" in
    index.md|memory.md|check-links.sh|.linkcheck-ignore|glossary.md|frame-manifest.txt) ;;
    *) say "one loose file too many in the ai/ root: $f (\`ai/rules/layout.md\` §2: ai/ holds subdirectories plus those few files only)";;
  esac
done < <(find ai -maxdepth 1 -type f)

if [ "$bad" -gt 0 ]; then echo; echo "LEDGER-FAIL ($bad mismatches)"; exit 1; fi
echo "LEDGER-OK (fields complete, double write agrees, index and entities line up)"
