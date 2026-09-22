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
V=0; [ "${1:-}" = "-v" ] && V=1
pass=0; fail=0; out=""

run() { # $1=name $2...=command
  local name="$1"; shift
  local o rc
  o=$("$@" 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '  ✅ %-22s %s\n' "$name" "$(tail -1 <<< "$o")"
    pass=$((pass+1))
  else
    # The summary for a red row takes the **verdict line** (`*-FAIL...`), not the second-to-last line --
    # that one picks up a blank line or a hint (measured: the ledger cell was blank every time). **All four seats read this table, so the summary has to say "how many".**
    local sum; sum=$(grep -E '\-FAIL' <<< "$o" | tail -1); [ -n "$sum" ] || sum=$(tail -2 <<< "$o" | head -1)
    printf '  ❌ %-22s %s\n' "$name" "$sum"
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

echo
if [ "$fail" -gt 0 ]; then
  [ "$V" = 1 ] && { echo "$out"; echo; }
  echo "ALL-FAIL ($pass green / $fail red)"
  [ "$V" = 0 ] && echo "  For the detail: bash ops/verify/check-all.sh -v"
  exit 1
fi
echo "ALL-OK ($pass guards all green)"
