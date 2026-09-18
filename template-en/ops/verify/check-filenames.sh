#!/usr/bin/env bash
# check-filenames: does the repo contain filenames that **cannot be created on Windows**?
# Usage: bash ops/verify/check-filenames.sh
# Exit 0 = all legal; 1 = illegal ones found (listed); 2 = wrong structure.
#
# Why this guard: AI sessions mostly run on Linux (a container or a mounted share), where `<` `>` `:` `|` `?` `*`
# are all legal characters and creating such a directory works fine. **On Windows they are illegal** --
# so the repo looks perfect on the Linux side and blows up the moment the Requester opens a GUI client on Windows:
#
#   fatal: git rm: '…/prototype/<project>/feature/index.md': Invalid argument
#
# **A real one**: the template's placeholder directory was named with angle brackets, and the rename to English kept them,
# right up until the Requester's SourceTree reported the error.
# **This failure has no symptom at all on the Linux side**, which is exactly why it needs a guard.
#
# It judges the thing being protected: whether **the path characters themselves** can exist on Windows,
# not whether someone wrote a placeholder in a document -- writing `<project>` in prose is correct, that is a placeholder;
# only **actually creating it as a directory or file** is a problem.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
bad=0
list() { find . -path ./.git -prune -o -print 2>/dev/null | sed 's|^\./||' | grep -v '^\.$'; }

# (1) illegal characters: < > : " | ? *   (/ and \ are separators, not judged here)
while IFS= read -r p; do
  [ -z "$p" ] && continue
  echo "  x  contains a character Windows forbids: $p"
  bad=$((bad+1))
done < <(list | grep -E '[<>:"|?*]' || true)

# (2) trailing dot or space (Windows silently strips them, so the two sides stop matching)
while IFS= read -r p; do
  [ -z "$p" ] && continue
  echo "  x  filename ends in a dot or a space (Windows silently strips it): $p"
  bad=$((bad+1))
done < <(list | grep -E '[ .]$' || true)

# (3) Windows reserved names (CON/PRN/AUX/NUL/COM1-9/LPT1-9, with or without an extension)
#     Note: judged with awk, not grep -E -- in grep -E a \t is the letter t, not a tab (learned the hard way)
while IFS= read -r p; do
  [ -z "$p" ] && continue
  echo "  x  a Windows reserved name; it cannot be created there: $p"
  bad=$((bad+1))
done < <(list | awk -F/ '{
    n=$NF; sub(/\..*$/,"",n); n=toupper(n);
    if (n=="CON"||n=="PRN"||n=="AUX"||n=="NUL"||n ~ /^COM[1-9]$/||n ~ /^LPT[1-9]$/) print $0
  }' || true)

# (4) names differing only in case (Windows and macOS are case-insensitive by default; the two overwrite each other)
while IFS= read -r p; do
  [ -z "$p" ] && continue
  echo "  x  two names differing only in case (they overwrite each other on Windows/macOS): $p"
  bad=$((bad+1))
done < <(list | awk '{ k=tolower($0); if (k in seen) { print seen[k]; print $0 } else seen[k]=$0 }' || true)

if [ "$bad" -gt 0 ]; then
  echo
  echo "FILENAMES-FAIL ($bad problems)"
  echo "  Do not use angle brackets for a placeholder directory -- use something like _PROJECT_."
  exit 1
fi
echo "FILENAMES-OK (no filename that Windows could not create)"
