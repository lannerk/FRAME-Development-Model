#!/usr/bin/env bash
# check-cachebust: the front end's `?v=` string must be a **computed content fingerprint**, never typed by hand.
# Usage: bash ops/verify/check-cachebust.sh          check only
#        bash ops/verify/check-cachebust.sh --fix    fix in place (the same shape as check-template-sync --accept)
# Exit codes: 0 = clean; 1 = something does not match; 2 = wrong structure.
#
# [Why this exists] Each script in the page carries a `?v=<something>` so browsers drop their cache.
# Change the script and **not** that string and the browser keeps the old file -- **shipped but not in
# effect**: the file really did change, the sha matches, the logs look fine. It is the hardest class to
# diagnose. Measured twice (a changed interface simply did not appear after shipping), while the rule
# about it was **only a sentence people had to remember, with no script checking it**. A rule with no
# guard is not a rule.
#
# [What is actually tested] That **the version string equals that file's content fingerprint**, not
# "was the number bumped". Nobody numbers anything, so "I forgot to change it" stops existing.
# The fingerprint is the first 8 lowercase hex characters of the sha256.
#
# [All four have to speak up, not just one]
#   (1) the string does not match the content (the common one: changed the js, forgot the string);
#   (2) a reference to a script that **does not exist** (typo, or the file was deleted and the reference left);
#   (3) a script of this family exists but the page **never references it** (added the file, forgot to hook it up);
#   (4) referenced but **with no `?v=` at all** -- that never expires, which is the same trap as (1).
#
# [Projects with a prototype mirror] The mirrored copy of the page is kept identical by check-mirror;
# this guard only looks at the source, so after `--fix` copy the page into the mirror again.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
# 🔴 **A project-specific path may never be hard-coded into FRAME** (the Requester's ruling of
# 2026-09-26): values come from `ops/verify/paths.env` (class seed; the template ships commented
# samples), overridable by environment variables. **Unconfigured means skip**, never red.
[ -f ops/verify/paths.env ] && . ops/verify/paths.env
WEB="${CACHEBUST_WEB:-}"
PAGE="${CACHEBUST_PAGE:-${WEB:+$WEB/index.html}}"
# 🔴 The script-name prefix is **each project's own** convention; only the criterion (version string =
# content fingerprint) is generic -- **the project-specific slot must be a knob, never hard-coded.**
PREFIX="${CACHEBUST_PREFIX:-}"

# Three knobs: `CACHEBUST_WEB` (the front-end directory) · `CACHEBUST_PAGE` (the page carrying the
# scripts) · `CACHEBUST_PREFIX` (the script-name prefix). **Unconfigured, no such page, or not one
# script of that family: skip**, not an error.
if [ -z "$WEB" ] || [ -z "$PREFIX" ] || [ -z "$PAGE" ] || [ ! -f "$PAGE" ]; then
  echo "CACHEBUST-SKIP (no front end configured -- set CACHEBUST_WEB= / CACHEBUST_PREFIX= in ops/verify/paths.env, or pass them as environment variables)"; exit 0
fi

fp() { # fingerprint = first 8 hex characters of the content's sha256
  # 🔴 Strip CR first: a Windows checkout turns one side into CRLF, and without stripping it the same
  # content fingerprints differently on two machines, so the guard would report a difference that is not one.
  tr -d '\r' < "$1" | sha256sum | cut -c1-8
}

FIX=0; [ "${1:-}" = "--fix" ] && FIX=1
bad=0; report=""; fixed=0

# Take every <script src="<prefix>*.js..."> exactly as written (query string included)
refs=$(grep -o "<script src=\"$PREFIX[^\"]*\"" "$PAGE" | sed 's/^<script src="//; s/"$//' | LC_ALL=C sort -u)
files=$(find "$WEB" -maxdepth 1 -type f -name "$PREFIX*.js" | LC_ALL=C sort)

if [ -z "$refs" ] && [ -z "$files" ]; then
  echo "CACHEBUST-SKIP (no $PREFIX*.js references in $PAGE and none under $WEB/; set CACHEBUST_PREFIX to your project's prefix)"
  exit 0
fi

for ref in $refs; do
  file=${ref%%\?*}
  q=${ref#"$file"}                  # "" or "?v=xxx"
  path="$WEB/$file"
  if [ ! -f "$path" ]; then
    report="$report  x $file -- the page references it, but there is no such file under $WEB/
"
    bad=$((bad+1)); continue
  fi
  want=$(fp "$path")
  if [ -z "$q" ]; then
    report="$report  x $file -- the reference has **no ?v=**, so this file's cache never expires; it should be ?v=$want
"
    bad=$((bad+1))
    [ "$FIX" = 1 ] && { sed -i "s|<script src=\"$file\"|<script src=\"$file?v=$want\"|g" "$PAGE"; fixed=$((fixed+1)); }
    continue
  fi
  have=${q#\?v=}
  if [ "$have" != "$want" ]; then
    report="$report  x $file -- the version string is $have, the content says it should be $want (changed the js, not the string => browsers keep the old one)
"
    bad=$((bad+1))
    [ "$FIX" = 1 ] && { sed -i "s|<script src=\"$file?v=$have\"|<script src=\"$file?v=$want\"|g" "$PAGE"; fixed=$((fixed+1)); }
  fi
done

while IFS= read -r path; do
  [ -n "$path" ] || continue
  n=$(basename "$path")
  grep -q "<script src=\"$n" "$PAGE" && continue
  report="$report  x $n -- the file exists under $WEB/ but the page never references it (added the file, forgot to hook it up?)
"
  bad=$((bad+1))
done <<< "$files"

n=$(printf '%s\n' "$refs" | grep -c .)

if [ "$FIX" = 1 ] && [ "$fixed" -gt 0 ]; then
  echo "CACHEBUST-FIXED ($fixed fixed; remember to copy the mirror again -- check-mirror watches that)"
  exec bash "$0"
fi

if [ "$bad" -gt 0 ]; then
  printf '%s' "$report"
  echo "CACHEBUST-FAIL ($bad mismatched; $n references on this page)"
  echo "  How to fix: bash ops/verify/check-cachebust.sh --fix, then copy $PAGE into the prototype mirror"
  exit 1
fi
echo "CACHEBUST-OK ($n references, every version string equals its file's fingerprint)"
