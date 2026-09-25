#!/usr/bin/env bash
# check-paths: scan every script for hard-coded old in-repo directory names.
# Usage: from the repo root, bash ops/verify/check-paths.sh
# Exit 0 = clean; 1 = hard-coded paths found (listed one by one).
# It scans for two things:
#  (1) **hard-coded private IPs** -- machines come and go, IPs change; the only source is ops/machines.json.
#      One IP appearing a hundred times in docs is normal; finding out on swap day is too late.
#  (2) **retired directory names** -- nobody rescans the scripts after a rename; every reorg leaves that debt.
#      Put this project's retired names into BAD_SCRIPT and this guard stops it happening twice.
set -u
# 🔴 **A read-only git call must never create an index.lock** (root cause reported by the Supervisor
# 2026-09-24, hit twice for real): the local Cowork workspace has **no delete permission by default**,
# while `git status` / `git diff` refresh the index as a side effect and **can create `.git/index.lock`
# without being able to remove it** -- so one guard run leaves a deadlock in the Requester's repository
# and every later commit (including his own in SourceTree) is blocked. The test is **"leave no lock in
# someone else's repo"**, not "does the script run". `GIT_OPTIONAL_LOCKS=0` makes git skip those optional
# locks; a real `add`/`commit` still takes its own lock and is unaffected.
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2

# Retired directory names + any absolute drive path; paths must come from ops/paths.ps1.
# In scripts: no retired names, no absolute drive paths, no hard-coded IPs -- scripts execute, a wrong one really runs wrong.
# <put this project's retired directory names below, separated by |; if none, keep only the IP and drive rules>
BAD_SCRIPT='[A-Za-z]:\\[A-Za-z]|(10|172|192)\.(1[6-9]|2[0-9]|3[01]|168|[0-9]+)\.[0-9]{1,3}\.[0-9]{1,3}'
# In docs: only hard-coded test-machine IPs matter. Docs may **narrate** history; that is a record, not configuration.
BAD_DOC='(10|172|192)\.(1[6-9]|2[0-9]|3[01]|168|[0-9]+)\.[0-9]{1,3}\.[0-9]{1,3}'

n=0
scan() {   # $1=file $2=regex
  hits=$(grep -nE "$2" "$1" 2>/dev/null | head -5)
  [ -z "$hits" ] && return 0
  echo "── $1"; printf '%s\n' "$hits" | sed 's/^/   /'
  n=$((n+1))
}

# Exemption list: ops/.pathcheck-ignore, one path prefix per line, # starts a comment.
# Every entry must say why it is exempt and when it goes away -- a temporary exemption with a task number counts, an open-ended one does not.
EX="$ROOT/ops/.pathcheck-ignore"
skip(){ [ -f "$EX" ] || return 1; while IFS= read -r l; do
          l="${l%%#*}"                      # strip trailing comment
          # [Trap] This used to be `tr -d '[:space:]'`, which strips **all** whitespace in the line, so
          # **a path containing a space (e.g. `Claude outputs/`) could never match — writing it did nothing**
          # (reported by the Developer seat on 2026-09-17; the "criterion looks present but does not fire" family).
          # Strip only leading/trailing whitespace; spaces inside the path must survive.
          l="$(printf '%s' "$l" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
          [ -z "$l" ] && continue
          case "${1#./}" in $l*) return 0;; esac
        done < "$EX"; return 1; }

while IFS= read -r f; do
  skip "$f" && continue
  # The single sources exempt themselves: paths.ps1 owns paths, machines.json owns machines;
  case "$f" in
    ./ops/paths.ps1|./ops/machines.json|./ops/verify/check-paths.sh|./ops/verify/check-root.sh|./docs/ops/realmachine.md|./MIGRATION.md) continue;;
    # Verbatim zone: not one word of the Requester's own words may change, including an IP he said out loud.
    # That is not configuration, it is a historical quote -- editing it falsifies the requirement record.
    ./product/requirements/inbox.md|./product/requirements/verbatim/*) continue;;
  esac
  case "$f" in
    *.md) scan "$f" "$BAD_DOC";;
    *)    scan "$f" "$BAD_SCRIPT";;
  esac
done < <(find . \( -name '*.ps1' -o -name '*.sh' -o -name '*.service' -o -name '*.md' \) \
          -not -path './.git/*' -not -path './tmp/*' -not -path './dist/*' \
          -not -path './archive/*' -not -path './_newroot/*' \
          | while IFS= read -r f; do
              # [Why git-ignored paths are skipped] A bare `find .` also scans what `.gitignore` excludes,
              # so a tool's own output directory gets judged red. **A guard should only judge what is in the repo**
              # (same criterion as `check-root.sh`: a tracked file is still judged).
              git ls-files --error-unmatch -- "$f" >/dev/null 2>&1 && { echo "$f"; continue; }
              git check-ignore -q -- "$f" 2>/dev/null || echo "$f"
            done)

if [ "$n" -gt 0 ]; then
  echo "CHECK-PATHS-FAIL ($n files hard-code a path or a test-machine IP)"
  echo "  Paths: dot-source ops/paths.ps1 and use \$Proj / \$Dist / \$Tmp / \$Outputs; do not assemble your own."
  echo "  Machines: read ops/machines.json and refer by id; never write an IP."
  exit 1
fi
echo "CHECK-PATHS-OK (no hard-coded in-repo paths, no hard-coded test-machine IPs)"
