#!/usr/bin/env bash
# check-debrand: **FRAME itself is independent of any specific project.**
# Usage: bash ops/verify/check-debrand.sh
#        DEBRAND_DIRS="<dirs...>" PRIVATE_WORDS=<list> bash ops/verify/check-debrand.sh   (for reverse assertions)
# Exit codes: 0 = clean (including "no list, skipped"); 1 = private content would be synced out.
#
# 🔴 **The Requester ruled on 2026-09-26**: "frame should also be independent of any specific project; if this
# was got wrong earlier, have the Maintainer update it." Written as one testable sentence: **FRAME itself (both
# templates, and the source repository they sync into) can be taken to a completely unrelated project without
# changing a single character.** So no host project's name, directory name, file-name prefix, private IP,
# commit id or session path may appear in a template.
#
# [What is tested] A **host-side private-word list** (`ops/verify/.private-words`, one word or regex per line,
# `#` for comments); a hit is red. 🔴 **The list itself is class skip and never syncs** -- shipping the words you
# are hiding into a public repository points them out to everyone.
#
# [Why there is no built-in "bad word list"] Only the host project knows which words are private (its own product
# name, directory names, subnet). Hard-coding them into FRAME would put project-specific content back into FRAME --
# this guard would be violating the very thing it protects.
#
# [Why the source repository is scanned too] What other people actually see is the **source repository**; the
# templates get there by syncing, so scanning only locally means "we never looked before publishing". The path comes
# from `home=` in `ai/frame-repo.conf`; without it, only the local tree is scanned.
#
# [Two exemptions, each with its reason]
#   . `ops/verify/.private-words` itself -- it *is* the list.
#   . `ai/FRAME-VERSION` and `ops/frame/.baseline*` -- this sync mechanism's own bookkeeping (`synced_with` records
#     the name of the repository synced with, which is provenance). Counting them would make **every sync report
#     itself red**, with deleting the provenance as the only fix.
set -u
# 🔴 A read-only git call must never create an index.lock (the local workspace may have no delete permission, and a
# leftover lock blocks every later commit).
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
WORDS="${PRIVATE_WORDS:-ops/verify/.private-words}"

if [ ! -f "$WORDS" ]; then
  echo "DEBRAND-SKIP (no private-word list at $WORDS -- normal for a new project; one word per line when you want one, and the list itself is class skip and never distributed)"
  exit 0
fi

DIRS="${DEBRAND_DIRS:-}"
if [ -z "$DIRS" ]; then
  for d in ai/template ai/template-en; do [ -d "$d" ] && DIRS="$DIRS $d"; done
  if [ -f ai/frame-repo.conf ]; then
    hp="$(sed -n 's/^home=//p' ai/frame-repo.conf | head -1)"
    [ -n "$hp" ] && [ ! -d "$hp" ] && hp="$HOME/mnt/$(basename "$(printf '%s' "$hp" | tr '\\' '/')")"
    for s in "$hp/ai" "$hp/ops"; do [ -n "$hp" ] && [ -d "$s" ] && DIRS="$DIRS $s"; done
  fi
fi
[ -n "$DIRS" ] || { echo "DEBRAND-SKIP (no template directory and no source repository -- this project does not publish FRAME)"; exit 0; }

hits=0
while IFS= read -r w; do
  case "$w" in ''|'#'*) continue;; esac
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$(grep -c -E -- "$w" "$f" 2>/dev/null || echo 0)
    echo "  x  private content \"$w\" appears in: $f ($n hits)"; hits=$((hits+1))
  done < <(grep -rlE --exclude-dir=.git -- "$w" $DIRS 2>/dev/null \
           | grep -v '/\.private-words$' | grep -v '/ai/FRAME-VERSION$' | grep -v '/ops/frame/\.baseline')
done < "$WORDS"

if [ "$hits" -gt 0 ]; then
  echo
  echo "DEBRAND-FAIL ($hits)"
  echo "  All of these ride into the **open-source repository** on the next sync. The criterion: **it can be taken to a"
  echo "  completely unrelated project without changing a single character.**"
  echo "  How to fix: project-specific paths go into ops/verify/paths.env (class seed); commit ids, machines and file"
  echo "  names in the stories become generic; keep the \"why\" behind each rule -- that is the reason it exists."
  exit 1
fi
echo "DEBRAND-OK (no host-project content in the templates or the source repository; scanned: $(echo $DIRS | tr ' ' ','))"
