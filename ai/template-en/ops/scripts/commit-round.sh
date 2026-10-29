#!/usr/bin/env bash
# commit-round: once the Reviewer seat has called a round, commit that round's changes to the **local** git.
# Usage: bash ops/scripts/commit-round.sh "<one-line title>" --seat <seat>   [--dry] [-- <only these paths...>]
#        Reviewer commits the Developer's work: bash ops/scripts/commit-round.sh ["<title>"] --seat developer --by reviewer --for "T-0010 B-0019"
#          (in the round that passes it; with no title, the first line of the code block in ai/state/now.md §7 is used; workflow.md §7b)
#        Archive commit (a stage is done, automated checks green, not yet reviewed): add --unreviewed; the title gets "unreviewed:" automatically (Requester 2026-10-05)
#        Shared files (mail . archive . memory): **those carrying your seat's name come along automatically; the rest only when named after `--`** (see "shared files are split by file name" below)
# Exit codes: 0 = committed (or the --dry run passed); 1 = a precondition is not met (exits as-is, nothing touched); 2 = the structure is wrong.
#
# [The boundary, not a word past it]
#   * **By default add + commit only, no push.** Pushing is the Requester's business (he uses SourceTree) --
#     **except in a project where the Requester authorised automatic pushes**: `auto-push=<remotes...>` in `ai/frame-repo.conf`; after a successful
#     commit, `git push <remote> <current branch>` for each, a failure is reported as-is, no retry, no credential changes, never `--force`
#     (Requester 2026-10-25 in one project: push to both remotes on every commit).
#   * **Never amend / rebase / reset / checkout / cherry-pick / force** -- those rewrite history,
#     and SourceTree has this repo open; a rewritten history shows up there as a tangle that has to be restored by hand.
#   * **Never touch git config** (`core.autocrlf` and the like are the Requester's Windows-side settings; touch them and the diff is fake from top to bottom).
#   * **Never create or switch a branch**, commit on the current one.
#
# [The four SourceTree-safe preflight checks] -- any one failing exits as-is: not an error, just "now is not the time to commit"
#   (1) `.git/index.lock` present -> SourceTree is working, **wait for it to finish**; grabbing the lock makes it error out on the spot;
#       `HEAD.lock` / the current branch's ref lock / `packed-refs.lock` present -> writing the branch must fail, **name them**, a human deletes after checking
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
TITLE=""; DRY=0; SEAT="${SEAT:-}"; ALLSEATS=0; BY=""; FOR=""; NARROW=(); UNREV=0
START=$(date +%s)
AUTOPUSH="$(grep -E '^auto-push=' ai/frame-repo.conf 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '\r')"; [ "$AUTOPUSH" = off ] && AUTOPUSH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --) shift; NARROW=("$@"); break;;
    --by) shift; BY="${1:-}";;
    --for) shift; FOR="${1:-}";;
    --dry) DRY=1;;
    --unreviewed) UNREV=1;;
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

# -- Committing on another seat's behalf: exactly one legal form (Requester 2026-09-30: once the review passes, the Reviewer seat commits the Developer's code too) --
# The Developer seat does not commit (committing your own work = bypassing review); its changes are committed by the Reviewer seat in the round
# that passes (task) or closes (bug) them -- **one commit for the Developer's files, one for the Reviewer's own**. No other "X commits for Y" is opened:
# that would empty the "Seat" line of meaning.
if [ -n "$BY" ]; then
  case "$BY" in reviewer|Reviewer|审查席) BY=Reviewer;; *) echo "STOP --by takes only reviewer (the only form is the Reviewer committing for the Developer)"; exit 2;; esac
  case "$SEAT" in developer|Developer|开发席) ;; *) echo "STOP --by reviewer goes only with --seat developer"; exit 2;; esac
  printf '%s' "$FOR" | grep -qE '(T|B)-[0-9]{4}' || { echo "STOP say which items passed: --for \"T-#### B-####\""; exit 2; }
  if [ -z "$TITLE" ] && [ -f ai/state/now.md ]; then
    TITLE="$(awk '/^## (七|7[.、])/{f=1;next} f&&/^## /{exit} f&&/^```/{c++;next} f&&c==1&&NF{print;exit}' ai/state/now.md)"
    [ -n "$TITLE" ] || { echo "STOP no title given, and the code block in ai/state/now.md §7 has no line to take"; exit 2; }
  fi
fi

# -- archive commit (Requester 2026-10-05): a Developer stage is done, that stage's automated checks and conformance tests
# are green and the task carries a self-test, so the Reviewer seat commits it before reviewing. **The history must show "this one
# was not reviewed"** -- so only the "Reviewer commits for the Developer" shape is accepted, and the script adds the title prefix
# rather than relying on someone remembering. A red guard follows the normal rule (ANYWAY=1, recorded in the message): the sweep
# often carries another seat's red, and a hard stop would mean an archive commit could never be made.
if [ "$UNREV" = 1 ]; then
  [ "$BY" = Reviewer ] || { echo "STOP --unreviewed is only for the Reviewer committing for the Developer: --seat developer --by reviewer --for \"T-####\" --unreviewed"; exit 2; }
  case "$TITLE" in unreviewed*) ;; *) TITLE="unreviewed: $TITLE";; esac
fi
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

# -- The other three locks a commit needs --
# [why] Only index.lock used to be checked. Reviewer seat 2026-10-15, measured: the previous commit left `.git/refs/heads/master.lock`, this check
# let it through, update-ref failed at the very end with `cannot lock ref`, and the hint pointed at HEAD.lock. Check every lock the commit writes, up front, **by name and age**.
STALE=""
for l in .git/HEAD.lock ".git/refs/heads/$br.lock" .git/packed-refs.lock; do
  [ -e "$l" ] && STALE="$STALE
     $l (untouched for $(( ($(date +%s) - $(stat -c %Y "$l")) / 60 )) min)"
done
if [ -n "$STALE" ]; then
  echo "⛔ these locks are present, so writing the branch will fail (cannot lock ref):$STALE"
  echo "   Most likely an interrupted earlier commit (this script or SourceTree). **Check in SourceTree that nothing is in progress first**, then delete them."
  echo "   (The Requester or a session with delete permission deletes them; **this script will not** -- if something really is running, deleting would wreck it.)"
  exit 1
fi

# -- a red guard blocks the commit --
# "Red means not done" is this method's basic criterion; committing with a red guard writes
# "not done" into history, and the next person to clone it thinks this is a clean baseline.
# 🔴 **Reuse the guard run** (Reviewer seat 2026-09-30, measured: on the mounted share check-all takes ~2 min, the script used to run it
# a second time on red just to list the red rows, and with `git commit` on top one call ran past the sandbox's 180 s limit, was killed and left locks).
# check-all writes every run to tmp/.check-all.last; **a result younger than 20 min is used as is** (CHECK_ALL_MAX_AGE seconds), otherwise it runs now.
# What is judged is "are the guards green before committing", not "run them once more".
LAST=tmp/.check-all.last; MAXAGE="${CHECK_ALL_MAX_AGE:-1200}"
if [ -f "$LAST" ] && [ $(( $(date +%s) - $(head -1 "$LAST" | cut -d' ' -f1) )) -le "$MAXAGE" ] 2>/dev/null; then
  GUARD_SRC="reusing the run from $(( ($(date +%s) - $(head -1 "$LAST" | cut -d' ' -f1)) / 60 )) min ago"
else
  bash ops/verify/check-all.sh >/dev/null 2>&1; GUARD_SRC="run now"
fi
GUARD="$(grep -aoE 'ALL-(OK|FAIL).*' "$LAST" 2>/dev/null | head -1)"
[ -n "$GUARD" ] || { echo "STOP no guard result ($LAST was not written)"; exit 2; }
GUARD="$GUARD ($GUARD_SRC)"
# 🔴 **A red does not block yet: decide once we know which files are being committed** (Supervisor 2026-10-27, forwarded by the
# Requester: a docs-only commit was blocked by another seat's over-budget task file, another by a "planned" path -- neither caused by
# the commit). The rule is in "guards: block only the reds this commit causes" below.
GUARD_RED=0
case "$GUARD" in
  ALL-FAIL*)
    if [ "${ANYWAY:-0}" != 1 ]; then GUARD_RED=1
    else GUARD="$GUARD (committed red, ANYWAY=1)"; fi
    ;;
esac

# -- File ownership: commit only your own (the single source is the ownership table in ai/rules/layout.md §7) --
# [Why this exists] The old version always ran `git add -A`, and **it twice swept files another seat was editing
# at that moment into its own commit**:
#   . once: the Maintainer's commit carried away the Reviewer's bug/task/state files and the Supervisor's report
#     (10 of 24 files were not its own);
#   . again: when the Reviewer committed, 6 files the Maintainer had just staged were nearly taken with it.
# **The commit message is history shared by all four seats; sweeping the wrong files in makes that history lie.**
# So: if the changes span more than one seat, stop and let a human pick.
# [exact first, then longest prefix] It used to take the first matching row: `product/*` sits above `product/requirements/requester-profile.md`,
# so the profile always went to the Reviewer and `--seat Supervisor` refused to commit it (Supervisor seat 2026-10-17, measured). Now **row order
# does not matter**: exact path > longer prefix > shorter prefix (that is what lets `.github/workflows/*` stand apart from a broader prefix).
SEAT_OF_FILE() {  # $1=path -> prints Maintainer/Reviewer/Developer/Supervisor/shared/-
  # [A script under `ops/scripts/` that is not on the FRAME manifest is the project's own, and belongs to the Developer]
  # (Requester 2026-10-29: while release scripts belonged to the Maintainer, every change meant a letter asking for review, 4 in two days).
  # `ai/frame-manifest.txt` lists the scripts FRAME ships; those stay with the Maintainer.
  case "$1" in ops/scripts/*) if [ -f ai/frame-manifest.txt ] && ! grep -qxF -- "$1" ai/frame-manifest.txt; then echo Developer; return; fi;; esac
  o="$(awk -v f="$1" '
    /^## / { sec = ($0 ~ /^## (七|7[.、])/); next }   # read only the section-7 table: other tables in layout.md mention seat names in column 3 too
    !sec { next }
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
        if (star) { sub(/\*$/, "", p); if (index(f, p) == 1 && length(p) > blen) { blen = length(p); best = owner } }
        else if (f == p) { exact = owner; exit }
      }
    }
    END { if (exact != "") print exact; else if (best != "") print best }' ai/rules/layout.md)"
  # [Anything under `ops/` that the table does not list and the FRAME manifest does not ship also goes to the Developer] (the project's own
  # deploy and release config, e.g. a release pipeline's skeleton directory; the Requester's 2026-10-29 call was "the project's own scripts belong
  # to the Developer", and these are the same kind of thing -- the Maintainer keeps FRAME's rules, not the product's release pipeline).
  if [ -z "$o" ]; then case "$1" in ops/*) if [ -f ai/frame-manifest.txt ] && ! grep -qxF -- "$1" ai/frame-manifest.txt; then o=Developer; fi;; esac; fi
  [ -n "$o" ] && printf '%s\n' "$o"
}
OWNERSHIP_SPLIT() {
  printf '%s\n' "$1" | grep . | while IFS= read -r f; do
    o=$(SEAT_OF_FILE "$f"); echo "${o:-unlisted}|$f"
  done
}

# --dry **never touches the index**: the Requester may already have staged exactly what he wants
# in SourceTree, and add -A followed by reset would wipe that choice (learned the hard way).
# 🔴 **Scan only what needs scanning** (Reviewer seat 2026-09-30, measured: on the mounted share a whole-repo `git diff --name-only` ran past 175 s,
# per package 0–21 s). With `-- <paths...>` only those are looked at; with --seat only the ownership table's paths for **that seat and "shared"**
# (the only files it may commit anyway); only with neither is the whole repo scanned. Cost: with --seat, "left for other seats" counts only that range.
SCOPE=()
if [ "${#NARROW[@]}" -gt 0 ]; then SCOPE=("${NARROW[@]}")
elif [ -n "$SEAT" ] && [ "$ALLSEATS" != 1 ]; then
  case "$SEAT" in maintainer|Maintainer|维护席) S0=Maintainer;; reviewer|Reviewer|审查席) S0=Reviewer;; developer|Developer|开发席) S0=Developer;;
    supervisor|Supervisor|监督席) S0=Supervisor;; researcher|Researcher|研究席) S0=Researcher;; *) S0="$SEAT";; esac
  while IFS= read -r ps; do [ -n "$ps" ] && SCOPE+=("$ps"); done < <(awk -v s="$S0" -F'|' '
    /^## / { sec = ($0 ~ /^## (七|7[.、])/); next }   # read only the section-7 table: other tables in layout.md mention seat names in column 3 too
    !sec { next }
    /^\|/ && !/^\|---/ { o=$3; if (o !~ s && o !~ /shared/) next
      n=split($2, ps, "·"); for (i=1;i<=n;i++){ p=ps[i]; gsub(/[` ]/,"",p); gsub(/^\*\*|\*\*$/,"",p); if (p!="") print p } }' ai/rules/layout.md | sort -u)
fi
if [ "$DRY" = 1 ]; then
  D_STAT="$(G diff HEAD --shortstat -- "${SCOPE[@]}" | sed 's/^ *//')"
  # [Why untracked files are included] `git diff` **cannot see newly created files**, so a task opened this round
  # was never picked up in --dry (measured and reported by the Reviewer seat, 2026-09-15). A real commit sees it
  # via `add -A`, so **only the rehearsal was blind** -- and a rehearsal that disagrees with the real commit is worse than none.
  D_FILES="$({ G diff HEAD --name-only -- "${SCOPE[@]}"; G ls-files --others --exclude-standard -- "${SCOPE[@]}"; } | grep . | sort -u)"
  [ -z "$D_FILES" ] && { echo "nothing to commit (the working tree is clean)."; exit 0; }
  CAND="$D_FILES"
else
  CAND="$({ G diff HEAD --name-only -- "${SCOPE[@]}"; G ls-files --others --exclude-standard -- "${SCOPE[@]}"; } | grep . | sort -u)"
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
# 🔴 **Shared files are split by file name** (the Requester's ruling, 2026-10-05). --seat used to count a "shared" file as
# wholly yours, so another seat's uncommitted change in the mail / archive / memory was swept along and signed with your
# name (measured twice: nothing lost, but the history was signed wrong).
# Now **files carrying your seat's name come along automatically** -- the drop-boxes you send from `to-*/from-<seat>.md`,
# the ones you receive in `to-<seat>/`, your archive `archive/<seat>-*`, your seat memory `seat-<seat>.md`; **the other
# shared files** (`ai/memory.md` and the like, where nobody can tell who changed them) **come along only when named after
# `-- <paths>`**; the unnamed ones are listed and stay in the working tree.
# One shape it cannot stop: two seats editing the same drop-box at once (the sender adds a row, the recipient moves one
# out) -- whoever commits first takes both. Rare; look at --dry before committing.
SHARED_LEFT=""
NOTE_SHARED() {
  [ -n "$SHARED_LEFT" ] || return 0
  echo "NOTE $(printf '%s\n' "$SHARED_LEFT" | grep -c .) shared file(s) changed but neither carry $SEAT's name nor were named, so they were **left out** (if the change is yours, run again with -- <paths...>):"
  printf '%s\n' "$SHARED_LEFT" | sed 's/^/     /'
}
if [ -n "$SEAT" ] && [ "$ALLSEATS" != 1 ]; then
  case "$SEAT" in Maintainer) SEAT_EN=maintainer;; Reviewer) SEAT_EN=reviewer;; Developer) SEAT_EN=developer;; Supervisor) SEAT_EN=supervisor;; Researcher) SEAT_EN=researcher;; *) SEAT_EN="-";; esac
  SHARED_AWK='function by_name(p) { return (p ~ ("^ai/mail/to-[^/]+/from-" en "[.]md$") || index(p, "ai/mail/to-" en "/") == 1 || index(p, "ai/mail/archive/" en "-") == 1 || p == ("ai/memory-archive/seat-" en ".md")) }'
  MINE="$(printf '%s\n' "$SPLIT" | awk -F'|' -v s="$SEAT" -v en="$SEAT_EN" -v named="${#NARROW[@]}" "$SHARED_AWK"'
    $1==s {print $2; next} $1=="shared" && (named > 0 || by_name($2)) {print $2}')"
  SHARED_LEFT="$(printf '%s\n' "$SPLIT" | awk -F'|' -v en="$SEAT_EN" -v named="${#NARROW[@]}" "$SHARED_AWK"'
    $1=="shared" && !(named > 0 || by_name($2)) {print $2}')"
  [ -z "$MINE" ] && { echo "STOP nothing in this round belongs to $SEAT (ownership table: ai/rules/layout.md §7)."; NOTE_SHARED; exit 1; }
  OTHERS="$(printf '%s\n' "$SPLIT" | awk -F'|' -v s="$SEAT" '$1!=s && $1!="shared" {print $1"|"$2}')"
fi
# With `-- <paths>` but no per-seat pick (--all-seats): commit only what changed under those paths; **never fall back to a whole-repo add -A**
[ -z "$MINE" ] && [ "${#NARROW[@]}" -gt 0 ] && MINE="$CAND"

# -- Guards: block only the reds this commit causes --
# The red detail is in tmp/.check-all.detail (check-all always saves it). **If it names any file being committed -> block**;
# if it names none, the red belongs to another seat or another place: commit, and record the reds in the message. No detail file
# (an older check-all, or just removed) -> cannot tell, block as before.
# 🔴 **Every round still has to end fully green** -- what passes here is only "unrelated to this commit"; those reds stay in the guard output for their owners.
if [ "$GUARD_RED" = 1 ]; then
  COMMITS="${MINE:-$CAND}"; DET=tmp/.check-all.detail; HIT=""
  # [findings only, not the hints] after its verdict line (`*-FAIL`) a red block often adds a "how to fix" line that names paths
  # (the budget one says "record it in ai/rules/maintenance-log.md" -- measured: it made the maintenance log look like "this commit's red").
  # So per block take only the lines after `── name ──` and before the first `-FAIL` line.
  FIND="$(mktemp "${TMPDIR:-/tmp}/cr_find.XXXXXX")"
  # One more narrowing (2026-10-29, measured): there are info lines before the verdict too -- the budget guard prints "fixed content = CLAUDE.md + laws.md ...",
  # which made a CLAUDE.md being committed look like this commit's red. So only **finding lines** count: lines with ✗ / x, broken-link lines,
  # the path guard's `── ./file` lines, and the continuation lines right after them indented 5+ spaces (the version guard lists files that way).
  [ -f "$DET" ] && awk '/^── .* ──$/ {k=1; c=0; next} /-FAIL/ {k=0} !k {next}
      /✗|^ *x  |^(断链|锚点断链|broken)|^── \.\// {print; c=1; next}
      c && /^     / {print; next} {c=0}' "$DET" > "$FIND"
  [ -f "$DET" ] && HIT="$(printf '%s\n' "$COMMITS" | grep . | while IFS= read -r f; do grep -aqF -- "$f" "$FIND" && echo "$f"; done)"
  rm -f "$FIND" 2>/dev/null
  if [ ! -f "$DET" ] || [ -n "$HIT" ]; then
    echo "BLOCKED: a guard is red: $GUARD"
    grep -a '❌' "$LAST" | sed 's/^/   /'
    if [ -n "$HIT" ]; then echo "   the red detail names files being committed:"; printf '%s\n' "$HIT" | sed 's/^/     /'
    else echo "   (no red detail $DET, so it cannot tell whose red it is -- rerun bash ops/verify/check-all.sh, then commit)"; fi
    echo "   Make it green first. **If you really must commit with it red** (say this round is the fix):"
    echo "   ANYWAY=1 bash $0 \"<title>\"   -- the commit message will say it went in red."
    exit 1
  fi
  REDS="$(grep -a '❌' "$LAST" | sed -E 's/^ *❌ *//; s/  +.*//' | awk '{printf "%s%s", (NR>1 ? ", " : ""), $0}')"
  echo "note: guards are red ($REDS), but no red names a file being committed, so this commits; the owners are in layout.md section 7, and **the round still has to end green**."
  GUARD="$GUARD (red, unrelated to this commit: $REDS; not blocked)"
fi

if [ "$DRY" != 1 ]; then
  if [ -n "$MINE" ]; then
    set --; while IFS= read -r f; do [ -n "$f" ] && set -- "$@" "$f"; done <<< "$(printf '%s\n' "$MINE" | grep .)"
    GIT_LITERAL_PATHSPECS=1 G add -A -- "$@"
  else
    G add -A
  fi
  if [ -n "$MINE" ]; then CHK=(-- "$@"); else CHK=(); fi
  if GIT_LITERAL_PATHSPECS=1 G diff --cached --quiet HEAD "${CHK[@]}"; then
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
# When committing for the Developer its files mostly live under src/ with no task ID in the name -- use the IDs from --for (that is "what passed this time")
if [ -n "$BY" ]; then
  tasks=$(printf '%s\n' "$FOR $tasks" | grep -oE 'T-[0-9]{4}' | sort -u | paste -sd' ' -)
  bugs=$(printf '%s\n' "$FOR $bugs" | grep -oE 'B-[0-9]{4}' | sort -u | paste -sd' ' -)
fi
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

BYNOTE=""; [ -n "$BY" ] && BYNOTE=" (committed by $BY after the review passed; for $FOR)"
[ "$UNREV" = 1 ] && BYNOTE=" (committed by $BY as an **archive commit, not yet reviewed**; for $FOR)"
PUSHNOTE="**not pushed** -- confirm in SourceTree, then push."; [ -n "$AUTOPUSH" ] && PUSHNOTE="pushed after commit per ai/frame-repo.conf to: $AUTOPUSH"
MSG=$(cat <<EOM
$TITLE

Date:      $(date '+%Y-%m-%d %H:%M')
Scope:     $files files ($stat)
Tasks:     ${tasks:-—}
bug:       ${bugs:-—}
Decisions: ${ads:-—}
Guards:    $GUARD
Seat:      ${SEAT:-unspecified (--all-seats, or only one seat has changes)}$BYNOTE${OTHERS:+
Left for other seats (not committed here): $(printf '%s\n' "$OTHERS" | awk -F"|" '{c[$1]++} END {for (k in c) printf "%s %d · ", k, c[k]}' | sed 's/ · $//')}

Generated by the Reviewer seat after calling a round; $PUSHNOTE

Co-Authored-By: Claude <noreply@anthropic.com>
EOM
)

if [ "$DRY" = 1 ]; then
  echo "-- dry run, nothing committed, **the index was not touched** --"; echo "$MSG"; echo; echo "(the file count on the Scope line is this same number, one source)"; NOTE_SHARED; exit 0
fi

# 🔴 **The real commit uses plumbing, not `git commit`** (Reviewer seat 2026-09-30, measured: on the mounted share `git commit` ran past 175 s three times
# in a row and was killed, leaving index.lock / HEAD.lock that block SourceTree; it is slow because it refreshes the whole index and stats the whole
# working tree). The four plumbing steps touch only these files, 1–10 s: a temporary index read from HEAD -> add only this commit's files ->
# write-tree -> commit-tree -> update-ref **with the old value** (compare-and-swap: if someone committed meanwhile it fails and changes nothing).
# **The temporary index** keeps whatever another seat staged in SourceTree out of this commit (what `git commit -- <paths>` --only used to mean).
MSGF="$(mktemp "${TMPDIR:-/tmp}/cr_msg.XXXXXX")" && TIDX="$(mktemp "${TMPDIR:-/tmp}/cr_idx.XXXXXX")" || { echo "STOP cannot create temp files; nothing committed."; exit 1; }
printf '%s\n' "$MSG" > "$MSGF"
OLD="$(G rev-parse --verify HEAD)"
ok=1
if [ -n "$MINE" ]; then
  GIT_INDEX_FILE="$TIDX" G read-tree HEAD || ok=0
  [ "$ok" = 1 ] && { GIT_INDEX_FILE="$TIDX" GIT_LITERAL_PATHSPECS=1 G add -A -- "$@" || ok=0; }
  [ "$ok" = 1 ] && TREE="$(GIT_INDEX_FILE="$TIDX" G write-tree)" || ok=0
else
  TREE="$(G write-tree)" || ok=0
fi
[ "$ok" = 1 ] && NEW="$(G commit-tree "$TREE" -p "$OLD" -F "$MSGF")" || ok=0
[ "$ok" = 1 ] && { G update-ref -m "commit (commit-round): $TITLE" "refs/heads/$br" "$NEW" "$OLD" || ok=0; }
rm -f "$MSGF" "$TIDX" 2>/dev/null

# -- Wrap-up: locks and temp objects this run left behind (**on success and on failure**) --
# With no delete permission in the sandbox, git can create locks it cannot remove (memory, type 6). **Only what appeared during this run**
# (mtime >= start) is touched; an older lock may be SourceTree's and is left alone. If one cannot be removed, say so, before the Requester hits it.
# [why find, not a list] It used to clear five hard-coded names, and only on success; Reviewer seat 2026-10-15 measured a commit that left
# `.git/refs/heads/master.lock`, and the next one hit `cannot lock ref` twice. Do not guess which locks git makes: **sweep every *.lock that appeared this run**.
# [trap] `-newermt` is strictly-newer, so a lock made in the same second would slip through; count from START-1.
left=""; tmpn=0
while IFS= read -r l; do
  [ -n "$l" ] || continue
  rm -f "$l" 2>/dev/null || left="$left $l"
done < <(find .git -path .git/objects -prune -o -name '*.lock' -newermt "@$((START-1))" -print 2>/dev/null
         find .git/objects -maxdepth 1 -name '*.lock' -newermt "@$((START-1))" 2>/dev/null)
while IFS= read -r t; do rm -f "$t" 2>/dev/null || tmpn=$((tmpn+1)); done < <(find .git/objects -name 'tmp_obj_*' -newermt "@$((START-1))" 2>/dev/null)
if [ "$ok" != 1 ]; then
  echo "the commit failed; the branch did not move ($br is still ${OLD:0:7})."
  [ -n "$left" ] && echo "⚠️  the locks this run left cannot be removed:$left -- ask once for delete permission on this folder, then remove them (this run created them)"
  OLDL="$(find .git -path .git/objects -prune -o -name '*.lock' -print 2>/dev/null)"
  [ -n "$OLDL" ] && { echo "   these locks are still in the repo (not from this run, most likely the cause; make sure SourceTree is idle before deleting):"; printf '%s\n' "$OLDL" | sed 's/^/     /'; }
  exit 1
fi
[ -n "$left" ] && echo "⚠️  committed, but the locks this run left cannot be removed:$left -- ask once for delete permission on this folder, then remove them (this run created them)"
[ "$tmpn" -gt 0 ] && echo "⚠️  $tmpn .git/objects/**/tmp_obj_* left by this run (harmless; remove them once you have delete permission)"
echo "✅ committed to the local branch $br: $(G rev-parse --short HEAD)"
echo "   $TITLE"
if [ -n "$AUTOPUSH" ]; then
  # Automatic push: only projects whose Requester authorised it have auto-push=; push the current branch to each remote, **no retry, no credentials, never --force**
  for r in $AUTOPUSH; do
    po="$(mktemp "${TMPDIR:-/tmp}/cr_push.XXXXXX")"
    if { command -v timeout >/dev/null 2>&1 && timeout "${PUSH_TIMEOUT:-150}" git push "$r" "$br" >"$po" 2>&1; } \
       || { ! command -v timeout >/dev/null 2>&1 && git push "$r" "$br" >"$po" 2>&1; }; then
      echo "   pushed $r/$br"
    else
      echo "   ⚠️  push to $r failed (no retry, credentials untouched; the commit is local):"; sed 's/^/        /' "$po" | tail -6
    fi
    rm -f "$po" 2>/dev/null
  done
  echo "   ($(( $(date +%s) - START )) s)"
else
  echo "   **not pushed** -- take a look in SourceTree before you push. ($(( $(date +%s) - START )) s)"
fi
NOTE_SHARED
