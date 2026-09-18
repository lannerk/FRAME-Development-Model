#!/usr/bin/env bash
# frame-scan: used when initializing a project -- split what is in the root into "ours" and "the old project's".
# Usage: bash ops/verify/frame-scan.sh
# Exit 0 = the scan finished (0 does NOT mean "no problems", only that it finished; a human reads the result).
#
# Background: this template is copied over the WHOLE root directory. After that the root holds two
# sets of things at once, and a new project has no template to compare against -- the ruler is
# ai/frame-manifest.txt (generated from the template).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
M="ai/frame-manifest.txt"
[ -f "$M" ] || { echo "cannot find $M -- this list ships with the template; without it you cannot tell which files are whose."; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
grep -v '^#' "$M" | grep -v '^[[:space:]]*$' | LC_ALL=C sort > "$TMP/ours"
find . -type f \
  -not -path './.git/*' -not -path './archive/*' \
  -not -path './dist/*'  -not -path './tmp/*' \
  -printf '%P\n' | LC_ALL=C sort > "$TMP/actual"

comm -12 "$TMP/ours" "$TMP/actual" > "$TMP/A"
comm -13 "$TMP/ours" "$TMP/actual" > "$TMP/B"
comm -23 "$TMP/ours" "$TMP/actual" | grep -Ev '^(archive|dist|tmp)/' > "$TMP/missing" || true

echo "=== A - ours (in the list and present): $(wc -l < "$TMP/A") files ==="
echo "    Leave them. But the ones whose CONTENT looks like the old project are class C name clashes -- look at each:"
echo "    most common: README.md  .gitignore  docs/  things under src/"
echo
echo "=== B - the old project's (not in the list): $(wc -l < "$TMP/B") files ==="
echo "    File them per ai/rules/layout.md. Produce a mapping table and get the Requester to confirm it before moving anything."
if [ -s "$TMP/B" ]; then
  echo "    -- top level first:"
  sed 's|/.*||' "$TMP/B" | LC_ALL=C sort -u | sed 's/^/      /'
  echo "    -- all of them (first 200 lines):"
  head -200 "$TMP/B" | sed 's/^/      /'
  [ "$(wc -l < "$TMP/B")" -gt 200 ] && echo "      ... and $(( $(wc -l < "$TMP/B") - 200 )) more; compare against $M yourself"
fi
echo
echo "=== in the list but missing now: $(wc -l < "$TMP/missing") files ==="
echo "    Usually the copy was incomplete, or an old file of the same name pushed it out. **Explain every one before moving on.**"
[ -s "$TMP/missing" ] && sed 's/^/      /' "$TMP/missing"
echo
echo "Note: archive/ dist/ tmp/ were not scanned (they hold odds and ends by design)."
echo "FRAME-SCAN-DONE (this means \"the scan finished\", not \"nothing is wrong\" -- a human reads the result)"
