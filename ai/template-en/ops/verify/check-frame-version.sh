#!/usr/bin/env bash
# check-frame-version: when the FRAME body changed, was the version stamped along with it.
# Usage: bash ops/verify/check-frame-version.sh
#       FV_ROOT=<another repo root> bash ops/verify/check-frame-version.sh   <- do reverse assertions on a copy
# Exit 0 = the version kept up (or n/a); 1 = a FRAME-body commit is newer than the last version stamp; 2 = bad structure.
#
# [Why this exists] "The fingerprint is for machines, the version is bumped by a person" -- and people forget. The rule used to live only in
# step 8 of the "sync FRAME" command, so when the Maintainer **edited the source repo directly, without that command**, nothing reminded it
# (measured 2026-09-28: layout.md changed and committed, no bump; the Requester spotted it at once). Downstream judges "am I caught up" by
# the version number; a version that does not move makes the change invisible to people.
#
# [It judges the thing worth keeping] Not mtime, not fingerprints: **git commit order** --
# the last commit touching the FRAME body (files `ops/frame/classes.txt` classes as follow, the version file itself excluded)
# must **be** or **precede** the last commit touching `ai/FRAME-VERSION`. Changing both in one commit counts as caught up.
# Uncommitted changes are ignored (that is commit time's business); a repo with templates runs this once per template (inside it).
set -u
export GIT_OPTIONAL_LOCKS=0
ROOT="${FV_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$ROOT" || exit 2
CL="ops/frame/classes.txt"; MF="ai/frame-manifest.txt"; VF="ai/FRAME-VERSION"
[ -f "$CL" ] && [ -f "$MF" ] || { echo "FRAME-VERSION-SKIP (no $CL or $MF; not a FRAME repo)"; exit 0; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "FRAME-VERSION-SKIP (not in git)"; exit 0; }
# Classification comes only from `ops/frame/frame-sync.sh --classify` (FRAME 1.11.0: one source for classification) -- **no second copy of
# the glob matching here**: a copy is a second criterion, a change to classes.txt reaches only one side, and the mismatch has no symptom
# (the 1.7.0 version of this script carried such a copy).
[ -f ops/frame/frame-sync.sh ] || { echo "FRAME-VERSION-SKIP (no ops/frame/frame-sync.sh)"; exit 0; }
F=()
while IFS=$'\t' read -r cls rel; do
  rel="${rel%$'\r'}"; [ "$cls" = follow ] || continue
  [ "$rel" = "$VF" ] && continue; [ -f "$rel" ] || continue
  F+=("$rel")
done < <(bash ops/frame/frame-sync.sh --classify 2>/dev/null)
[ "${#F[@]}" -gt 0 ] || { echo "FRAME-VERSION-SKIP (no follow-class files in the manifest)"; exit 0; }
lf="$(git log -1 --format=%H -- "${F[@]}" 2>/dev/null)"
[ -n "$lf" ] || { echo "FRAME-VERSION-OK (the FRAME body has no commits yet)"; exit 0; }
lv="$(git log -1 --format=%H -- "$VF" 2>/dev/null)"
ver="$(grep -E '^version:' "$VF" 2>/dev/null | head -1 | awk '{print $2}')"
if [ -n "$lv" ] && git merge-base --is-ancestor "$lf" "$lv" 2>/dev/null; then
  echo "FRAME-VERSION-OK (${#F[@]} FRAME-body files; the last commit is stamped in ${ver:-?})"; exit 0
fi
echo "  ✗  last FRAME-body commit $(git log -1 --format='%h %ad "%s"' --date=format:'%m-%d %H:%M' "$lf" | cut -c1-90)"
echo "     is newer than the last version stamp ${lv:+$(git log -1 --format='%h %ad' --date=format:'%m-%d %H:%M' "$lv")} (now ${ver:-no version file})"
echo "     FRAME-body files it touched: $(git show --name-only --format= "$lf" -- "${F[@]}" | head -5 | tr '\n' ' ')"
echo "     Fix: the Maintainer picks the number (structure/roles=major · rule semantics=minor · wording=patch), bash ops/frame/frame-sync.sh --stamp <version>, and puts the version in the commit message"
echo "FRAME-VERSION-FAIL (the FRAME body changed without a version stamp)"; exit 1
