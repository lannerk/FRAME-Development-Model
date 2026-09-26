#!/usr/bin/env bash
# check-advisor: the kickoff advisor library (ai/advisor/) is guarded on **two things**, not on "does the file exist".
# Usage: bash ops/verify/check-advisor.sh
#        ADVISOR_DIR=<a copy> bash ops/verify/check-advisor.sh   break it on a copy (for reverse assertions)
# Exit codes: 0 = pass (including "not applicable, skipped"); 1 = something is wrong; 2 = wrong structure.
#
# 🔴 **The two things it protects**:
#   (1) **Every recommendation can say why, and when it does not apply.** A card that only says
#       "use Go" gets copied as a default, while the whole value of this library is "why this is
#       recommended and what happens otherwise". The test is on **each card's and each question's own
#       parts**, not on "the word why appears somewhere in the file".
#   (2) **Not one word of private content may stay in here** -- this directory syncs into the
#       **open-source repository**. The test is a **host-side private-word list**
#       (`ops/verify/.private-words`, one word per line, `#` for comments):
#       🔴 **the list itself is class skip and is never distributed** -- shipping it would publish
#       exactly the words you are hiding.
#
# [Why there is no "all files must be present" test] The library grows over time, and a missing
# `domains/*` is a normal state; **making completeness red only pushes people to create empty files**,
# and an empty file is worse than none (it makes people think they checked).
set -u
# 🔴 **A read-only git call must never create an index.lock** (root cause reported 2026-09-24, hit
# twice for real): the local workspace may have **no delete permission**, while `git status` / `git diff`
# refresh the index as a side effect and **can create `.git/index.lock` without being able to remove it**
# -- one guard run then leaves a deadlock in the Requester's repository and every later commit is
# blocked. The test is **"leave no lock in someone else's repo"**, not "does the script run".
# `GIT_OPTIONAL_LOCKS=0` makes git skip those optional locks; a real `add`/`commit` still takes its own.
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
D="${ADVISOR_DIR:-ai/advisor}"
WORDS="${PRIVATE_WORDS:-ops/verify/.private-words}"
PROFILE="${PROFILE_PATH:-product/requirements/requester-profile.md}"
CLASSES="${CLASSES_FILE:-ops/frame/classes.txt}"

# Not applicable means skip: a project without the library must not be blocked by a test that does not apply
[ -d "$D" ] || { echo "ADVISOR-SKIP (no $D -- this project has no kickoff advisor, skipping)"; exit 0; }

bad=0

# -- (1) a choice card has all its parts -------------------------------------
# One card = one `### heading`, under which "Recommendation" and "Why" must be findable;
# **at least one of "Does not apply" and "Reversible" must be there** -- some cards really do apply
# everywhere, but then they must say what is reversible, or the reader cannot tell whether following
# the advice can be undone later.
if [ -f "$D/stack.md" ]; then
  awk -v RS='\n### ' 'NR>1{
      split($0, L, "\n"); title=L[1];
      hasR = ($0 ~ /Recommendation/); hasW = ($0 ~ /Why/);
      hasN = ($0 ~ /Does not apply/) || ($0 ~ /Reversible/);
      if (!hasR || !hasW || !hasN) {
        printf "  x  choice card \"%s\" is missing: %s%s%s\n", title,
          (hasR?"":"Recommendation "), (hasW?"":"Why "), (hasN?"":"Does not apply / Reversible");
        c++
      }
    } END{ exit (c>0?1:0) }' "$D/stack.md" || bad=$((bad+1))
fi

# -- (2) every question can say why it is asked, and what to recommend -------
# One question = a line `**<letter><digit> ...**` (A1, B2 ...). The test is on **that question's own**
# parts, not on the words appearing somewhere in the file (testing the file is testing a shadow: one
# mention in the preamble would keep it green forever).
if [ -f "$D/questions.md" ]; then
  python3 - "$D/questions.md" <<'PY' || bad=$((bad+1))
import re, sys
src = open(sys.argv[1], encoding='utf-8').read()
blocks = re.split(r'\n(?=\*\*[A-Z]\d+\s)', src)
missing = []
for b in blocks[1:]:
    title = b.split('\n', 1)[0].strip().strip('*')[:40]
    if 'Why ask' not in b: missing.append((title, 'Why ask'))
    elif 'Recommend' not in b: missing.append((title, 'Recommend'))
for t, w in missing:
    print(f"  x  question \"{t}\" is missing \"{w}\" -- a question with no \"Why ask\" gets skipped, and one with no \"Recommend\" hands the choice back to someone who is not technical")
sys.exit(1 if missing else 0)
PY
fi

# -- (3) the profile must be class seed, and must not live in the library ----
if [ -f "$CLASSES" ]; then
  if ! grep -qE "^seed[[:space:]]+${PROFILE//\//\\/}$" "$CLASSES"; then
    echo "  x  $PROFILE is not class seed in $CLASSES -- the profile is private project content,"
    echo "     and marking it follow would push the Requester's preferences **into the open-source repo** (an irreversible leak)."
    bad=$((bad+1))
  fi
fi
if [ -f "$D/$(basename "$PROFILE")" ]; then
  echo "  x  the profile does not belong in $D/ -- that directory is class follow and gets synced out."; bad=$((bad+1))
fi

# -- (4) the private-word test **moved out** ---------------------------------
# After the Requester ruled on 2026-09-26 that "frame should also be independent of any specific project",
# that test no longer covers only this library but **both templates and the source repository** -- it now
# lives in `ops/verify/check-debrand.sh`.
# 🔴 **Leaving it here would make the red say the wrong thing**: a product name left in
# `gitignore.template` reporting "the kickoff advisor is not up to standard" only sends people to read the
# library. **One guard protects one thing, and its red must say which thing.**

if [ "$bad" -gt 0 ]; then
  echo
  echo "ADVISOR-FAIL ($bad)"
  exit 1
fi
echo "ADVISOR-OK (cards complete, every question has Why ask and Recommend, the profile is seed; private words are check-debrand's job)"
