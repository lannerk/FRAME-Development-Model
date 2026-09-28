#!/usr/bin/env bash
# check-shell-strict: in a script with `set -u`, **a function reads $1 bare AND at least one call site passes nothing**.
# Usage: bash ops/verify/check-shell-strict.sh
#        SHELL_STRICT_DIRS="<dirs...>" bash ops/verify/check-shell-strict.sh   <- point it at a COPY for reverse assertions
# Exit 0 = the shape is absent (or N/A); 1 = present.
#
# 【Why this exists】Measured once, expensively: a shared script opened with `set -eu`, a function did `local q=$1`,
# and one call site passed **no argument** -- `set -u` calls it an unbound variable, `set -e` exits the whole script
# on the spot, and **every install depending on that script failed on that machine**, with one line in the log:
# "unbound variable". It names neither the function nor the call. **The fix is one character: `${1:-}`.**
#
# 【It judges the thing, not its textual shadow】
# 🔴 The first version judged "a bare $1 appears inside a function" and produced **55 hits, nearly all false**:
# `$2` inside `awk '{print $2}'` is awk's field, not a positional parameter, and a **mandatory** argument read bare
# is fine (the caller always passes it). A criterion that ships with dozens of historical reds **gets muted**.
# So it is narrowed to the measured shape: **a bare $1 at the definition** AND **a call in the same file with no argument**.
#
# 【Report how many files were scanned】per `ai/specs/testing.md` §0a R2: an empty scan is RED --
# a guard that scans nothing is green forever, and that is the most dangerous green there is.
set -u
cd "$(dirname "$0")/../.." || exit 2
DIRS="${SHELL_STRICT_DIRS:-ops src scripts bin}"
n=0; files=0
for d in $DIRS; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    grep -qE '^[[:space:]]*set[[:space:]]+-[a-z]*u' "$f" || continue   # no -u: not applicable
    files=$((files+1))
    out="$(awk '
      function strip(s,   r) { r=s; gsub(/#.*/,"",r); gsub(/'"'"'[^'"'"']*'"'"'/,"",r); return r }
      /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/ {
        fname=$0; sub(/[[:space:]]*\(\).*/,"",fname); gsub(/^[[:space:]]+/,"",fname)
        cur=fname; next
      }
      cur != "" {
        l=strip($0)
        if (l ~ /\$1([^:={+?\-0-9]|$)/ || l ~ /\$\{1\}/) bare[cur]=1
        if ($0 ~ /^\}/) cur=""
      }
      { lines[NR]=$0 }
      END {
        for (i=1;i<=NR;i++) {
          # 🔴 At a call site strip comments only, **not single quotes**: `foo ''` passes an EMPTY STRING,
          # which is still an argument. (The first version reused the definition-side strip and called it "no args" -- a false red.)
          l=lines[i]; sub(/#.*/,"",l)
          if (l ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/) continue
          for (fn in bare) {
            pat="(^|;|&&|\\|\\||\\{)[[:space:]]*" fn "[[:space:]]*(;|&&|\\|\\||$|#|\\))"
            if (l ~ pat) printf "%d: %s  <-  function %s reads $1 bare; this call passes nothing\n", i, lines[i], fn
          }
        }
      }' "$f")"
    [ -n "$out" ] || continue
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      echo "  ✗  $f:$h"
      n=$((n+1))
    done <<< "$out"
  done < <(find "$d" -name '*.sh' -type f | LC_ALL=C sort)
done
if [ "$files" = 0 ]; then
  echo "SHELL-STRICT-SKIP (no .sh with set -u under $DIRS -- not applicable)"; exit 0
fi
if [ "$n" -gt 0 ]; then
  echo "SHELL-STRICT-FAIL ($n; scanned $files scripts with set -u)"
  echo "  Fix: write \${1:-} in that function (or \${1:?missing argument} when it is mandatory), or pass the argument at the call."
  exit 1
fi
echo "SHELL-STRICT-OK (scanned $files scripts with set -u; no function reads \$1 bare with a no-argument call)"
