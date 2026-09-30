#!/usr/bin/env bash
# check-all: run every guard in one go and print one table.
# Usage: bash ops/verify/check-all.sh          run them all
#        bash ops/verify/check-all.sh -v       print the red ones together with their detail
# Exit codes: 0 = all green; 1 = something is red.
#
# [Why this exists] When the Requester says "I think development has drifted, go check",
# the Maintainer seat should not read the output of seven or eight scripts into context one by one -- that is pure token burn.
# This one runs **everything a machine can judge in one go** and answers with one table; **only the red ones are worth a human's time**.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
# [Every run is saved to tmp/.check-all.last] (first line: the start epoch and HEAD, then the whole table)
# The commit script uses it for 20 minutes instead of running everything again -- on the mounted share this table takes two minutes, and running it
# again at commit time makes one call time out, get killed and leave locks (Reviewer seat 2026-09-30, measured). The start time is stored: conservative.
if [ -z "${CHECK_ALL_INNER:-}" ]; then
  # 🔴 **Write to a temp file unique to this run, then rename it over the result**: several seats running the guards at once is normal, and a shared
  # intermediate file gets truncated under each other, leaving NUL holes (Maintainer seat 2026-09-30, measured: one .last with 653 NULs and the first
  # 6 rows gone, so the commit script could not read the verdict line).
  mkdir -p tmp; t0=$(date +%s); body="$(mktemp "${TMPDIR:-/tmp}/check-all.XXXXXX")"
  CHECK_ALL_INNER=1 bash "$0" "$@" | tee "$body"; rc=${PIPESTATUS[0]}
  nf="$(mktemp tmp/.check-all.last.XXXXXX)" && { echo "$t0 $(git rev-parse --short HEAD 2>/dev/null)"; cat "$body"; } > "$nf" && mv -f "$nf" tmp/.check-all.last
  rm -f "$body" 2>/dev/null
  exit "$rc"
fi
V=0; [ "${1:-}" = "-v" ] && V=1
pass=0; fail=0; out=""

run() { # $1=name $2...=command
  local name="$1"; shift
  local o rc t1 dt
  t1=$(date +%s); o=$("$@" 2>&1); rc=$?; dt=$(( $(date +%s) - t1 ))
  # every row carries its time: on the mounted share the slowest few (ledger, links) count against the 180 s per call; seen, they can be managed
  if [ "$rc" -eq 0 ]; then
    printf '  ✅ %-22s %s (%ss)\n' "$name" "$(tail -1 <<< "$o")" "$dt"
    pass=$((pass+1))
  else
    # The summary for a red row takes the **verdict line** (`*-FAIL...`), not the second-to-last line --
    # that one picks up a blank line or a hint (measured: the ledger cell was blank every time). **All four seats read this table, so the summary has to say "how many".**
    local sum; sum=$(grep -E '\-FAIL' <<< "$o" | tail -1); [ -n "$sum" ] || sum=$(tail -2 <<< "$o" | head -1)
    printf '  ❌ %-22s %s (%ss)\n' "$name" "$sum" "$dt"
    fail=$((fail+1))
    out="$out
── $name ──
$o"
  fi
}

echo "Guard sweep · $(date '+%Y-%m-%d %H:%M')"
echo
[ -x ai/check-links.sh ]                  && run "link check"     bash ai/check-links.sh
[ -x ops/verify/check-paths.sh ]          && run "hardcoded paths/IPs" bash ops/verify/check-paths.sh
[ -x ops/verify/check-inbox.sh ]          && run "inbox"          bash ops/verify/check-inbox.sh
[ -x ops/verify/check-bugs.sh ]           && run "bug loop"       bash ops/verify/check-bugs.sh
[ -x ops/verify/check-ledger.sh ]         && run "ledger"         bash ops/verify/check-ledger.sh
[ -x ops/verify/check-budget.sh ]         && run "line budget"    bash ops/verify/check-budget.sh
[ -x ops/verify/check-filenames.sh ]      && run "filenames"         bash ops/verify/check-filenames.sh
[ -x ops/verify/check-entrypoints.sh ]    && run "entry files"    bash ops/verify/check-entrypoints.sh
[ -x ops/verify/check-root.sh ]           && run "repo root"        bash ops/verify/check-root.sh
[ -x ops/verify/check-css-namespace.sh ]  && run "css namespace"    bash ops/verify/check-css-namespace.sh
[ -x ops/verify/check-mirror.sh ]         && run "source vs mirror"  bash ops/verify/check-mirror.sh
[ -x ops/verify/check-mail.sh ]           && run "seat mail"        bash ops/verify/check-mail.sh
[ -x ops/verify/check-writeback.sh ]      && run "write-back parked" bash ops/verify/check-writeback.sh
[ -x ops/verify/check-template-sync.sh ]  && run "template sync"  bash ops/verify/check-template-sync.sh
[ -x ops/verify/check-cachebust.sh ]     && run "web cache-bust"  bash ops/verify/check-cachebust.sh
[ -x ops/verify/check-randd.sh ]         && run "R&D line"       bash ops/verify/check-randd.sh
[ -x ops/verify/check-frame-version.sh ] && run "FRAME version"  bash ops/verify/check-frame-version.sh
[ -x ops/verify/check-shell-strict.sh ] && run "shell strict"  bash ops/verify/check-shell-strict.sh
[ -x ops/verify/check-css-selfref.sh ]  && run "css self-ref"  bash ops/verify/check-css-selfref.sh
[ -x ops/verify/check-advisor.sh ]       && run "kickoff advisor" bash ops/verify/check-advisor.sh
[ -x ops/verify/check-debrand.sh ]       && run "de-branding   " bash ops/verify/check-debrand.sh

# -- 🔴 The project's own guards: `ops/verify/check-project-*.sh` are auto-discovered ----------
# 【Why this hook exists】the table above belongs to **FRAME itself** (class follow -- a sync overwrites it).
# A project inevitably grows guards that only hold for it (a component inventory, an API reconcile, a glossary),
# and **adding a row to that table = writing project content into FRAME**: measured once -- a project's
# maintainer edited check-all.sh to register its own guard, so that file became "target changed" there and
# **every distribution needed a human merge**, while merging it into the template would have pushed that
# project's guard to every project. So the hook is on the FILE NAME, not in the table:
# drop `ops/verify/check-project-*.sh` in and it runs. The word `project` in the name is the reminder --
# **it never enters the template** (class skip in `ops/frame/classes.txt`).
# Same contract as every row above: print one `*-OK` line when green, exit non-zero when red, SKIP when N/A.
for pc in ops/verify/check-project-*.sh; do
  [ -x "$pc" ] || continue
  run "project guard" bash "$pc"
done

echo
if [ "$fail" -gt 0 ]; then
  [ "$V" = 1 ] && { echo "$out"; echo; }
  echo "ALL-FAIL ($pass green / $fail red · ${SECONDS}s total)"
  [ "$V" = 0 ] && echo "  For the detail: bash ops/verify/check-all.sh -v"
  exit 1
fi
echo "ALL-OK ($pass guards all green · ${SECONDS}s total)"
