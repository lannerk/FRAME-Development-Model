#!/usr/bin/env bash
# commit-round: once the Reviewer seat has called a round, commit that round's changes to the **local** git.
# Usage: bash ops/scripts/commit-round.sh "<one-line title>"   [--dry]
# Exit codes: 0 = committed (or the --dry run passed); 1 = a precondition is not met (exits as-is, nothing touched); 2 = the structure is wrong.
#
# [The boundary, not a word past it]
#   * **add + commit only. Never push.** Pushing is the Requester's business (he uses SourceTree).
#   * **Never amend / rebase / reset / checkout / cherry-pick / force** -- those rewrite history,
#     and SourceTree has this repo open; a rewritten history shows up there as a tangle that has to be restored by hand.
#   * **Never touch git config** (`core.autocrlf` and the like are the Requester's Windows-side settings; touch them and the diff is fake from top to bottom).
#   * **Never create or switch a branch**, commit on the current one.
#
# [The four SourceTree-safe preflight checks] -- any one failing exits as-is: not an error, just "now is not the time to commit"
#   (1) `.git/index.lock` present -> SourceTree is working, **wait for it to finish**; grabbing the lock makes it error out on the spot
#   (2) a merge / rebase / cherry-pick in progress -> committing now folds a half-finished state in
#   (3) HEAD detached -> the commit lands somewhere with no branch, invisible in SourceTree
#   (4) nothing to commit -> do not manufacture an empty commit
#
# [Why -c core.fileMode=false] This script runs off a mounted drive, and the executable bit the Linux side sees
# differs from the Windows side; leave it on and a pile of "mode change 100644 -> 100755" goes into the commit --
# pure noise, and it turns SourceTree's diff red from top to bottom.
set -u
# 🔴 **A read-only git call must never create an index.lock** (root cause reported by the Supervisor
# 2026-09-24, hit twice for real): the local Cowork workspace has **no delete permission by default**,
# while `git status` / `git diff` refresh the index as a side effect and **can create `.git/index.lock`
# without being able to remove it** -- so one guard run leaves a deadlock in the Requester's repository
# and every later commit (including his own in SourceTree) is blocked. The test is **"leave no lock in
# someone else's repo"**, not "does the script run". `GIT_OPTIONAL_LOCKS=0` makes git skip those optional
# locks; a real `add`/`commit` still takes its own lock and is unaffected.
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
TITLE=""; DRY=0; SEAT="${SEAT:-}"; ALLSEATS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry) DRY=1;;
    --all-seats) ALLSEATS=1;;
    --seat) shift; SEAT="${1:-}";;
    --seat=*) SEAT="${1#--seat=}";;
    *) [ -z "$TITLE" ] && TITLE="$1";;
  esac
  shift
done
[ -d .git ] || { echo "this is not a git repo root"; exit 2; }

# Identity: this machine (the mounted share / cloud container) has no global git identity; the
# Requester's identity lives in his Windows-side global config, which is not visible here.
# **Do not write it into .git/config** (that would override his global identity, and it counts as
# touching git config). Take it from **the author of the last commit** and pass it with `-c`
# instead, so the author in history matches what he normally commits as and SourceTree does not
# sprout an unfamiliar author. If it cannot be read, say so and let him decide.
AUTH_N="$(git log -1 --pretty='%an' 2>/dev/null || true)"
AUTH_E="$(git log -1 --pretty='%ae' 2>/dev/null || true)"
G() {
  if [ -n "$AUTH_N" ] && [ -n "$AUTH_E" ]; then
    git -c core.fileMode=false -c core.quotepath=false -c user.name="$AUTH_N" -c user.email="$AUTH_E" "$@"
  else
    git -c core.fileMode=false -c core.quotepath=false "$@"
  fi
}

# -- preflight checks --
if [ -f .git/index.lock ]; then
  age=$(( $(date +%s) - $(stat -c %Y .git/index.lock) ))
  sz=$(stat -c %s .git/index.lock)
  echo "⛔ .git/index.lock is present -- some git is working on this repo, and committing now would break it."
  if [ "$sz" -eq 0 ] && [ "$age" -gt 600 ]; then
    echo "   That said, this lock is **0 bytes and has not moved for $((age/60)) minutes**, which looks like a stale lock left by a git that never finished."
    echo "   **Go check in SourceTree that nothing is in progress first**, and only then delete it: rm .git/index.lock"
    echo "   (The Requester or the Developer seat deletes it; **this script will not delete it for you** -- if something really is running, deleting it destroys that.)"
  else
    echo "   Wait for it to finish, then run again. **Do not delete that lock file.**"
  fi
  exit 1
fi
for m in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
  [ -e ".git/$m" ] && { echo "⛔ the repo is in an unfinished $m state; finish it in SourceTree first."; exit 1; }
done
br=$(G symbolic-ref --quiet --short HEAD || true)
[ -z "$br" ] && { echo "⛔ HEAD is detached, not on any branch. Switch back to a branch first."; exit 1; }

# -- a red guard blocks the commit --
# "Red means not done" is this method's basic criterion; committing with a red guard writes
# "not done" into history, and the next person to clone it thinks this is a clean baseline.
GUARD="$(bash ops/verify/check-all.sh 2>/dev/null | grep -oE 'ALL-(OK|FAIL).*' | head -1)"
case "$GUARD" in
  ALL-FAIL*)
    if [ "${ANYWAY:-0}" != 1 ]; then
      echo "BLOCKED: a guard is red: $GUARD"
      bash ops/verify/check-all.sh 2>/dev/null | grep '❌' | sed 's/^/   /'
      echo "   Make it green first. **If you really must commit with it red** (say this round is the fix):"
      echo "   ANYWAY=1 bash $0 \"<title>\"   -- the commit message will say it went in red."
      exit 1
    fi
    GUARD="$GUARD (committed red, ANYWAY=1)"
    ;;
esac

# -- File ownership: commit only your own (the single source is the ownership table in ai/rules/layout.md §7) --
# [Why this exists] The old version always ran `git add -A`, and **it twice swept files another seat was editing
# at that moment into its own commit**:
#   . `acf7217`: the Maintainer's commit carried away the Reviewer's bug/task/state files and the Supervisor's report
#     (10 of 24 files were not its own);
#   . `992ed79`: when the Reviewer committed, 6 files the Maintainer had just staged were nearly taken with it.
# **The commit message is history shared by all four seats; sweeping the wrong files in makes that history lie.**
# So: if the changes span more than one seat, stop and let a human pick.
SEAT_OF_FILE() {  # $1=path -> prints Maintainer/Reviewer/Developer/Supervisor/shared/-
  awk -v f="$1" '
    /^\|/ {
      line=$0
      if (line ~ /^\|---/) next
      n=split(line, c, "|")
      if (n < 3) next
      paths=c[2]; owner=c[3]
      gsub(/^[ \t]+|[ \t]+$/, "", owner)
      if (owner !~ /(Maintainer|Reviewer|Developer|Supervisor|Researcher|shared)/) next
      if (owner ~ /shared/) owner="shared"
      else if (owner ~ /Maintainer/) owner="Maintainer"
      else if (owner ~ /Reviewer/) owner="Reviewer"
      else if (owner ~ /Developer/) owner="Developer"
      else if (owner ~ /Supervisor/) owner="Supervisor"
      else if (owner ~ /Researcher/) owner="Researcher"  # R&D line, writes only under ai/RandD/
      m=split(paths, ps, "·")
      for (i=1; i<=m; i++) {
        p=ps[i]
        gsub(/[` ]/, "", p)          # [trap] the first version also stripped *, turning every glob row into an exact match
        gsub(/^\*\*|\*\*$/, "", p)   # drop bold markers but **keep a trailing glob ***
        if (p == "") continue
        star = (p ~ /\*$/)
        if (star) { sub(/\*$/, "", p); if (index(f, p) == 1) { print owner; exit } }
        else if (f == p) { print owner; exit }
      }
    }' ai/rules/layout.md
}
OWNERSHIP_SPLIT() {
  printf '%s\n' "$1" | grep . | while IFS= read -r f; do
    o=$(SEAT_OF_FILE "$f"); echo "${o:-unlisted}|$f"
  done
}

# --dry **never touches the index**: the Requester may already have staged exactly what he wants
# in SourceTree, and add -A followed by reset would wipe that choice (learned the hard way).
if [ "$DRY" = 1 ]; then
  D_STAT="$(G diff HEAD --shortstat | sed 's/^ *//')"
  # [Why untracked files are included] `git diff` **cannot see newly created files**, so a task opened this round
  # was never picked up in --dry (measured and reported by the Reviewer seat, 2026-09-15). A real commit sees it
  # via `add -A`, so **only the rehearsal was blind** -- and a rehearsal that disagrees with the real commit is worse than none.
  D_FILES="$({ G diff HEAD --name-only; G ls-files --others --exclude-standard; } | grep . | sort -u)"
  [ -z "$D_FILES" ] && { echo "nothing to commit (the working tree is clean)."; exit 0; }
  CAND="$D_FILES"
else
  CAND="$({ G diff HEAD --name-only; G ls-files --others --exclude-standard; } | grep . | sort -u)"
  [ -z "$CAND" ] && { echo "nothing to commit (the working tree is clean)."; exit 0; }
fi

# -- the cross-seat stop --
SPLIT="$(OWNERSHIP_SPLIT "$CAND")"
SEATS_TOUCHED="$(printf '%s\n' "$SPLIT" | cut -d'|' -f1 | grep -v '^shared$' | sort -u | grep . || true)"
NSEATS="$(printf '%s\n' "$SEATS_TOUCHED" | grep -c . || true)"
MINE=""
if [ -n "$SEAT" ]; then
  case "$SEAT" in
    maintainer|Maintainer) SEAT=Maintainer;;
    reviewer|Reviewer)     SEAT=Reviewer;;
    developer|Developer)   SEAT=Developer;;
    supervisor|Supervisor) SEAT=Supervisor;;
    researcher|Researcher) SEAT=Researcher;;
    *) echo "STOP --seat takes one of: maintainer / reviewer / developer / supervisor / researcher"; exit 2;;
  esac
fi
if [ "$ALLSEATS" != 1 ] && [ "$NSEATS" -gt 1 ] && [ -z "$SEAT" ]; then
  echo "STOP this round's changes span $NSEATS seats, so there is no one name to commit under (ownership table: ai/rules/layout.md §7):"
  printf '%s\n' "$SPLIT" | sort | awk -F'|' '{printf "   %-11s %s\n", $1, $2}'
  echo
  echo "   commit only your own: bash ops/scripts/commit-round.sh \"<title>\" --seat maintainer"
  echo "   really commit everything (e.g. the Requester asked you to): add --all-seats; the message will say so."
  echo "   [Why the stop] The commit message is history shared by all four seats; sweeping in another seat's work makes it lie (measured twice, see layout.md §7)."
  exit 1
fi
if [ -n "$SEAT" ] && [ "$ALLSEATS" != 1 ]; then
  MINE="$(printf '%s\n' "$SPLIT" | awk -F'|' -v s="$SEAT" '$1==s || $1=="shared" {print $2}')"
  [ -z "$MINE" ] && { echo "STOP nothing in this round belongs to $SEAT (ownership table: ai/rules/layout.md §7)."; exit 1; }
  OTHERS="$(printf '%s\n' "$SPLIT" | awk -F'|' -v s="$SEAT" '$1!=s && $1!="shared" {print $1"|"$2}')"
fi

if [ "$DRY" != 1 ]; then
  if [ -n "$MINE" ]; then
    printf '%s\n' "$MINE" | grep . | while IFS= read -r f; do G add -- "$f"; done
  else
    G add -A
  fi
  if G diff --cached --quiet; then
    echo "nothing to commit (the working tree is clean)."; exit 0
  fi
fi

if [ "$DRY" = 1 ]; then
  names="${MINE:-$D_FILES}"; diffsrc="HEAD"; base=HEAD
else
  names="${MINE:-$(G diff --cached --name-only)}"; diffsrc="--cached"; base=--cached
fi
# [Why the stat is limited too] Unlimited, "Scope" reports the whole repo's file count while the commit holds fewer
# (the Reviewer seat reported "the two file counts disagree" on 2026-09-15). Limited, the two numbers share one source.
if [ -n "$MINE" ]; then
  # xargs spawns a subprocess and cannot see the shell function G -- the first version failed with `xargs: G: not found`.
  set --
  while IFS= read -r f; do [ -n "$f" ] && set -- "$@" "$f"; done <<< "$(printf '%s\n' "$MINE" | grep .)"
  stat=$(G diff "$base" --shortstat -- "$@" | sed 's/^ *//')
else
  stat=$(G diff "$base" --shortstat | sed 's/^ *//')
fi
[ -z "$stat" ] && stat="no line-level diff (all newly created files)"
newn=$(G ls-files --others --exclude-standard | grep -c . || true)
if [ -n "$MINE" ]; then
  newn=$(comm -12 <(printf '%s\n' "$MINE" | grep . | LC_ALL=C sort) <(G ls-files --others --exclude-standard | LC_ALL=C sort) | grep -c . || true)
fi
[ "${newn:-0}" -gt 0 ] && stat="$stat; $newn newly created"
files=$(printf '%s\n' "$names" | grep -c .)
tasks=$(printf '%s\n' "$names" | grep -oE 'T-[0-9]{4}' | sort -u | paste -sd' ' -)
bugs=$(printf '%s\n' "$names"  | grep -oE 'B-[0-9]{4}' | sort -u | paste -sd' ' -)
# [Decision IDs: judge "what was decided this round", not "what the prose mentions"]
# The old criterion `^\+.*\bAD[0-9]{3,4}\b` harvested a textual shadow; the Reviewer seat reported three false positives
# on 2026-09-15: (1) the diff's own `+++ b/ai/decisions/AD0501-0600.md` line, split into AD0501 / AD600;
# (2) prose that merely **cites** an older decision; (3) the "next free number" row in `ai/decisions/index.md`.
# New criterion: only **added table rows** in `ai/decisions/AD####-####.md` whose first cell is the ID itself
# (`| AD538 | ...`) -- **that is what "decided this round" means**. Prefer missing one: over-harvesting makes the commit message lie.
ads=$(G diff $diffsrc -- 'ai/decisions/AD[0-9]*-[0-9]*.md' \
      | grep -E '^\+\|[[:space:]]*(\*\*)?AD[0-9]{3,4}(\*\*)?[[:space:]]*\|' \
      | grep -oE 'AD[0-9]{3,4}' | sort -u | head -12 | paste -sd' ' -)
# A brand-new range file (added whole) has no "+| ADxxx |" context diff, so catch that case separately
if [ -z "$ads" ]; then
  ads=$(printf '%s\n' "$names" | grep -E '^ai/decisions/AD[0-9]+-[0-9]+\.md$' \
        | while IFS= read -r f; do [ -f "$f" ] && grep -oE '^\|[[:space:]]*(\*\*)?AD[0-9]{3,4}' "$f" | grep -oE 'AD[0-9]{3,4}'; done \
        | sort -u | head -12 | paste -sd' ' -)
fi
[ -z "$TITLE" ] && TITLE="Round $(date '+%m%d') changes ($files files)"

MSG=$(cat <<EOM
$TITLE

Date:      $(date '+%Y-%m-%d %H:%M')
Scope:     $files files ($stat)
Tasks:     ${tasks:-—}
bug:       ${bugs:-—}
Decisions: ${ads:-—}
Guards:    $GUARD
Seat:      ${SEAT:-unspecified (--all-seats, or only one seat has changes)}${OTHERS:+
Left for other seats (not committed here): $(printf '%s\n' "$OTHERS" | awk -F"|" '{c[$1]++} END {for (k in c) printf "%s %d · ", k, c[k]}' | sed 's/ · $//')}

Generated by the Reviewer seat after calling a round; **not pushed** -- confirm in SourceTree, then push.

Co-Authored-By: Claude <noreply@anthropic.com>
EOM
)

if [ "$DRY" = 1 ]; then
  echo "-- dry run, nothing committed, **the index was not touched** --"; echo "$MSG"; echo; echo "(the file count on the Scope line is this same number, one source)"; exit 0
fi

if [ -n "$MINE" ]; then
  # **path-limited commit**: another seat may already have staged things in SourceTree, and a commit without paths
  # would take them along.
  set --
  while IFS= read -r f; do [ -n "$f" ] && set -- "$@" "$f"; done <<< "$(printf '%s\n' "$MINE" | grep .)"
  G commit -q -m "$MSG" -- "$@" || { echo "the commit failed; nothing was changed."; exit 1; }
else
  G commit -q -m "$MSG" || { echo "the commit failed; nothing was changed."; exit 1; }
fi
echo "✅ committed to the local branch $br: $(G rev-parse --short HEAD)"
echo "   $TITLE"
echo "   **not pushed** -- take a look in SourceTree before you push."
