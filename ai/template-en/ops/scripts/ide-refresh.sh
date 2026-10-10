#!/usr/bin/env bash
# ide-refresh: see whether the tool implementation files in ai/ide/ need updating (ai/ide/README.md section 3, step 1).
# Usage: bash ops/scripts/ide-refresh.sh <tool>|--all
# It does three things only: where there is an npm package, compare `npm view` with version: in the header; otherwise print version-url for a person to look at; flag checked: older than 90 days as "stale". Then print the docs: pages to re-read.
# [Why only these] It runs in the repo and cannot read web pages (vendors' doc sites often forbid scraping and move their paths); the version number is the only thing it can judge reliably. Whether the docs changed is README section 3 step 2, read by a person.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
DIR="${IDE_DIR:-ai/ide}"
hdr(){ awk 'NR==1 && /^---[[:space:]]*$/ {f=1; next} f && /^---[[:space:]]*$/ {exit} f {print}' "$1"; }
hval(){ hdr "$1" | grep -E "^$2:" | head -1 | sed "s/^$2:[[:space:]]*//; s/[[:space:]]*#.*$//; s/^\"//; s/\"$//"; }
[ $# -ge 1 ] || { echo "usage: bash ops/scripts/ide-refresh.sh <tool>|--all"; exit 2; }
if [ "$1" = --all ]; then
  set -- $(for f in "$DIR"/*.md; do [ -f "$f" ] && b=$(basename "$f" .md) && [ "$b" != README ] && echo "$b"; done)
  [ $# -ge 1 ] || { echo "no implementation files in $DIR"; exit 2; }
fi
now=$(date +%s)
for t in "$@"; do
  f="$DIR/$t.md"; [ -f "$f" ] || f="$DIR/_spare/$t.md"
  [ -f "$f" ] || { echo "x $t: no such implementation file in $DIR"; continue; }
  npm="$(hval "$f" npm)"; ver="$(hval "$f" version)"; chk="$(hval "$f" checked)"; vurl="$(hval "$f" version-url)"
  out="$t (recorded ${ver:-?}, checked ${chk:-?})"
  if [ -n "$npm" ] && [ "$npm" != none ] && command -v npm >/dev/null 2>&1; then
    cur="$(timeout 30 npm view "$npm" version 2>/dev/null | tail -1)"
    if [ -z "$cur" ]; then out="$out: npm could not answer (no network, or the package was renamed)"
    elif [ "$cur" = "$ver" ]; then out="$out: unchanged"
    else out="$out: changed $ver -> $cur, check it per $DIR/README.md section 3 step 2"; fi
  else out="$out: no npm package (or no npm here), go and look at ${vurl:-(no version-url in the header)}"; fi
  if ts=$(date -d "$chk" +%s 2>/dev/null); then d=$(( (now - ts) / 86400 )); [ "$d" -gt 90 ] && out="$out . stale ($d days)"; fi
  echo "$out"
  hdr "$f" | awk '/^docs:/ {f=1; next} f && /^[[:space:]]+- / {sub(/^[[:space:]]+- /, "    re-read: "); print; next} f {exit}'
done
