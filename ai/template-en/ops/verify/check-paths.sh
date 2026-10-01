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
# 【Only what git can see】= tracked files (still present in the worktree) + untracked files not stopped by .gitignore
# (a freshly written file is exactly there). This used to `find` the whole tree: tmp/, node_modules/, build output and
# the to-be-deleted folders that sessions leave behind were all walked, although the criteria exclude them anyway -- and they were
# the bulk (measured: 65% of one repo's 25,000 files were git-ignored; on a mounted disk one guard took over a minute and
# the full guard table no longer fit in one call). **What git ignores never enters the repo; checking it is wasted.**
# The exclusions below are unchanged -- they just no longer have to be walked first. Outside a git repo (before
# `git init` at initialization) this falls back to find.
# A tracked file just deleted from the worktree stays in the list (`ls-files -d` costs 39 s on a mounted disk):
# reading it yields nothing, so no criterion is affected.
VIS="$(mktemp)"; trap 'rm -f "$VIS"' EXIT
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  { git -c core.quotepath=false ls-files -c; git -c core.quotepath=false ls-files -o --exclude-standard; } 2>/dev/null \
    | LC_ALL=C sort -u | sed 's|^|./|' > "$VIS"
else
  find . \( -path ./.git -o -name node_modules \) -prune -o -type f -print 2>/dev/null > "$VIS"
fi

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
    # clear-to-delete.sh joined 2026-10-01: its whole job is to find the `_to_delete/` sessions leave behind, so the name has to be in it.
    ./ops/paths.ps1|./ops/machines.json|./ops/verify/check-paths.sh|./ops/verify/check-root.sh|./ops/scripts/clear-to-delete.sh|./docs/ops/realmachine.md|./MIGRATION.md) continue;;
    # Verbatim zone: not one word of the Requester's own words may change, including an IP he said out loud.
    # That is not configuration, it is a historical quote -- editing it falsifies the requirement record.
    ./product/requirements/inbox.md|./product/requirements/verbatim/*) continue;;
  esac
  case "$f" in
    *.md) scan "$f" "$BAD_DOC";;
    *)    scan "$f" "$BAD_SCRIPT";;
  esac
done < <(grep -E '\.(ps1|sh|service|md)$' "$VIS" | grep -vE '^\./\.git/.*$|^\./tmp/.*$|^\./dist/.*$|^\./archive/.*$|^\./_newroot/.*$')

# -- 🔴 Third test: a script may not put a backtick inside a double-quoted echo ----------
# [Why this exists] This is the same trap this method has now hit **six times**: writing a hint in markdown
# habit and quoting a path or a flag name in backticks -- while **a backtick inside double quotes is command
# substitution**, so the guard "executes" its own message the moment it goes red. Real incidents include
# executing a handbook and printing 4467 lines of recursive errors, and creating 43 zero-byte junk files at
# the repo root. **`bash -n` cannot see it** (the syntax is perfectly legal); it only explodes when that line
# is reached, so it stayed a thing people had to remember -- and six times, people did not.
# The test looks at **non-comment lines** only (explaining the trap in a comment is legitimate; the first
# version reported its own explanation as a violation).
# [No retroactivity] Per ai/rules/workflow.md §3c, the gate is the **git commit time a file first entered**
# (never mtime -- a clone resets it): files added after that date go red, older ones are a note for their
# owning seat to fix.
BQ_SINCE="${BACKTICK_SINCE:-2026-09-27}"
nbq=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  # 🔴 An ESCAPED backtick (\`) inside double quotes is a **literal**, not command substitution.
  # Strip those first, otherwise this check flags correct code (measured: one such false positive
  # on a real script). sed keeps the line count, so grep -n line numbers still match the file.
  hits=$(sed 's/\\`//g' "$f" | grep -nE '^[[:space:]]*[^#]*echo[[:space:]]+"[^"]*`' | cut -d: -f1)
  [ -n "$hits" ] || continue
  a=$(git log --diff-filter=A --format=%cs -1 -- "$f" 2>/dev/null)
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if [ -n "$a" ] && [ "$a" \< "$BQ_SINCE" ]; then
      echo "  .  $f:$line has a backtick inside a double-quoted echo (entered the repo $a; §3c, not retroactive -- the owning seat fixes it)"
    else
      echo "  x  $f:$line -- a backtick inside a double-quoted echo is command substitution: the message gets run as a command (hit six times)"
      nbq=$((nbq+1))
    fi
  done <<< "$hits"
# 🔴 **Untracked new scripts are scanned too**: `git ls-files` cannot see them, and **a fresh mistake is
# exactly where they are** (the first reverse assertion fell into this: an uncommitted script, and the guard
# said nothing -- the same trap as adding `--others` to `--dry` earlier). So both lists are used: tracked,
# plus untracked-and-not-ignored.
done < <( { git -c core.quotepath=false ls-files -- '*.sh'; \
            git -c core.quotepath=false ls-files --others --exclude-standard -- '*.sh'; } 2>/dev/null \
          | grep -vE '^(ai/template|ai/template-en)/' | LC_ALL=C sort -u )
if [ "$nbq" -gt 0 ]; then
  echo "CHECK-PATHS-FAIL ($nbq backticks inside double-quoted echos)"
  echo "  Use plain text or drop the quotes in a message; use \$( ) when you really mean a command. **bash -n cannot catch this.**"
  exit 1
fi

if [ "$n" -gt 0 ]; then
  echo "CHECK-PATHS-FAIL ($n files hard-code a path or a test-machine IP)"
  echo "  Paths: dot-source ops/paths.ps1 and use \$Proj / \$Dist / \$Tmp / \$Outputs; do not assemble your own."
  echo "  Machines: read ops/machines.json and refer by id; never write an IP."
  exit 1
fi
echo "CHECK-PATHS-OK (no hard-coded in-repo paths, no hard-coded test-machine IPs)"
