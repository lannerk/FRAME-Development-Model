#!/usr/bin/env bash
# clear-to-delete: remove the _to_delete/ directories AI sessions leave in the repo -- **never one that holds a git-tracked file**. For the Requester.
# Usage (from anywhere inside the repo): bash ops/scripts/clear-to-delete.sh        list first, ask once, then delete
#                         bash ops/scripts/clear-to-delete.sh -y     delete without asking
#       Windows: double-click ops\scripts\clear-to-delete.bat (same criterion)
#
# 【Why this exists】AI sessions working in a linked-computer workspace have no delete permission by default,
# so whatever they cannot delete is moved into a _to_delete/ next to it, for the Requester to delete.
# These directories end up all over the repo, one can hold thousands of files (measured once: 5,686),
# and every guard walks them on every run.
# 【Criterion】Delete a _to_delete/ only if **not one file in it is tracked by git**: if something moved in there
# used to be in git, git sees the old place as "deleted" and the new one as "untracked", so it still goes;
# **a tracked file in there means someone committed it -- leave it alone.**
# node_modules/ and .git/ are not searched (none would be there, and walking them is slow).
set -u
export GIT_OPTIONAL_LOCKS=0
yes=0; case "${1:-}" in -y|--yes|/y) yes=1;; esac
root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not inside a git repository"; exit 2; }
cd "$root" || exit 2

list=(); kept=0
while IFS= read -r d; do
  d="${d#./}"
  if [ -n "$(git ls-files -- "$d" 2>/dev/null | head -1)" ]; then
    echo "  . skipped (holds git-tracked files; look at it in your git client first): $d"; kept=$((kept+1)); continue
  fi
  list+=("$d")
done < <(find . \( -path ./.git -o -name node_modules \) -prune -o -type d -name _to_delete -print -prune 2>/dev/null)

if [ "${#list[@]}" -eq 0 ]; then echo "CLEAR-TO-DELETE-OK (no _to_delete directory to clean)"; exit 0; fi
echo "These ${#list[@]} _to_delete directories can go:"
for d in "${list[@]}"; do echo "  $d ($(find "$d" -type f 2>/dev/null | wc -l) files)"; done
if [ "$yes" != 1 ]; then
  a=""; read -r -p "Delete them? Type y and press Enter: " a || true
  case "$a" in y|Y) ;; *) echo "Nothing deleted."; exit 0;; esac
fi
fail=0
for d in "${list[@]}"; do
  rm -rf -- "$d" 2>/dev/null
  if [ -e "$d" ]; then echo "  x could not delete: $d"; fail=$((fail+1)); fi
done
[ "$fail" -eq 0 ] || { echo "CLEAR-TO-DELETE-FAIL ($fail could not be deleted -- usually no delete permission, or a file is in use)"; exit 1; }
echo "CLEAR-TO-DELETE-OK (deleted ${#list[@]} directories)"
