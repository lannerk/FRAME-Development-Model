#!/usr/bin/env bash
# frame-sync -- what the command word "sync FRAME" actually does: bring this project's FRAME and the
# source repository into line, **without either side losing anything**.
#
# Usage (run from this project's root):
#   bash ops/frame/frame-sync.sh --status                   this repo's role, version and fingerprint
#   bash ops/frame/frame-sync.sh --sync                     reconcile both ways (**report only, writes nothing**)
#   bash ops/frame/frame-sync.sh --sync --apply             write both sides, once you have read the report
#   bash ops/frame/frame-sync.sh --adopt <repo>             take "what both sides look like now" as the baseline (first run; look before you adopt)
#   bash ops/frame/frame-sync.sh --adopt-mine               the same, but the baseline records **this project's copy**
#                                                           (whoever took this from GitHub uses this on the first run: later source changes count as "the source changed it" -> pulled in)
#   bash ops/frame/frame-sync.sh --classify                 each template file's class (follow/seed/skip), for the guards
#   bash ops/frame/frame-sync.sh --diff <repo> <rel-path>   what exactly differs in one file
#   bash ops/frame/frame-sync.sh --dry-run <targets...>    **distribute** to other projects, report only (home/host)
#   bash ops/frame/frame-sync.sh --dist --apply <targets...>  **distribute** and write into the targets
# 🔴 **`--apply <target>` is not "distribute and write"**: a bare `--apply` takes the "reconcile with the source"
#    side, where a positional argument is read as **the source repository**. Measured once: `--apply ../<a consumer>`
#    pulled 542 of that project's files into this repo's template. It now **errors out** (see the flag parsing).
# Exit codes: 0 = aligned, or the report is done; 1 = something needs a human; 2 = wrong structure or arguments.
#
# 🔴 Five iron rules (all of them in the code, none of them slogans):
#   1 source working tree dirty -> refuse --apply (**only committed FRAME counts**: ship a half-finished rule and
#     everyone downstream gets a rule nobody has verified)
#   2 target working tree dirty -> refuse to write (conflicts would get tangled up with local changes)
#   3 dry-run by default; --apply must be given explicitly
#   4 **never delete**: if the source dropped a file, only report it
#   5 re-record the baseline after apply / adopt
#
# 【What must hold】
#   · **The fingerprint is for the machine, the version number is for people**: the fingerprint is the aggregate
#     hash of every follow-class file, computed automatically; the version is bumped by the Maintainer.
#     Judge by the version alone and one forgotten bump makes the old look new (check-template-sync v1 fell into
#     the same family of trap by using mtime).
#   · **Compare content, not bytes**: strip CR first. Measured: README-zh_CN.md is CRLF, and a byte comparison
#     reports all 292 lines as "changed".
#   · **seed by default; only what is listed explicitly is follow**: miss a new file in the classes table and the
#     result is that it gets created, never that it overwrites what the target already had. The other way round,
#     one missing line silently loses something **with no symptom at all**.
set -u
# 🔴 **A read-only git call must never create an index.lock** (root cause reported by the Supervisor
# 2026-09-24, hit twice for real): the local Cowork workspace has **no delete permission by default**,
# while `git status` / `git diff` refresh the index as a side effect and **can create `.git/index.lock`
# without being able to remove it** -- so one guard run leaves a deadlock in the Requester's repository
# and every later commit (including his own in SourceTree) is blocked. The test is **"leave no lock in
# someone else's repo"**, not "does the script run". `GIT_OPTIONAL_LOCKS=0` makes git skip those optional
# locks; a real `add`/`commit` still takes its own lock and is unaffected.
export GIT_OPTIONAL_LOCKS=0
SELF="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$SELF/../.." && pwd)"
MODE="sync"; APPLY=0; ADOPT_MINE=0; DIST=0; STAMP_V=""; TARGETS=(); DIFF_T=""; DIFF_P=""; CLASSES="$SELF/classes.txt"
SAW_APPLY=0; SAW_SYNC=0; SAW_DIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --sync) MODE="sync"; SAW_SYNC=1 ;;
    --status|--fingerprint|--adopt|--classify) MODE="${1#--}" ;;
    --adopt-mine) MODE="adopt"; ADOPT_MINE=1 ;;
    --stamp) MODE="stamp"; STAMP_V="${2:-}"; shift ;;
    --dist) DIST=1; SAW_DIST=1 ;;   # the distribution side (the default is two-way reconciliation with the source)

    --dry-run) MODE="dist"; DIST=1 ;;
    # 🔴 **`--apply` no longer guesses**: it only turns writing on; which side to take is said explicitly with
    # `--sync` or `--dist`. The old version treated "MODE is still the default sync" as reconcile, so
    # `--apply <target>` quietly reconciled and took the target for the source repository (measured: 542 files
    # pulled into this repo's template). **An ambiguous default is far more dangerous than an error.**
    --apply) APPLY=1; SAW_APPLY=1; [ "$MODE" = "sync" ] || { MODE="dist"; DIST=1; } ;;
    --diff) MODE="diff"; DIFF_T="${2:-}"; DIFF_P="${3:-}"; shift 2 ;;
    --classes) CLASSES="${2:-}"; shift ;;
    -*) echo "unknown argument: $1"; exit 2 ;;
    *) TARGETS+=("$1") ;;
  esac; shift
done
[ -f "$CLASSES" ] || { echo "classes table not found: $CLASSES"; exit 2; }

# -- The repo profile (ai/frame-repo.conf) ---------------------------------
# 🔴 No repository name is hard-coded in this script: adding a project means adding one conf file.
conf_get() { [ -f "$1/ai/frame-repo.conf" ] || { echo ""; return; }
  grep -E "^$2=" "$1/ai/frame-repo.conf" | head -1 | cut -d= -f2-; }
conf_all() { [ -f "$1/ai/frame-repo.conf" ] || return 0
  grep -E "^$2=" "$1/ai/frame-repo.conf" | cut -d= -f2-; }
role_of() { local r; r="$(conf_get "$1" role)"; [ -n "$r" ] && { echo "$r"; return; }
  if [ -d "$1/ai/template" ] && [ ! -d "$1/src" ]; then echo home
  elif [ -d "$1/ai/template" ]; then echo host; else echo consumer; fi; }
# Where FRAME lives in a repo: the template directory if it has one, otherwise the project root
# 🔴 A repository may hold two templates (Chinese / English). **Sync one at a time**, naming the other
# with FRAME_TEMPLATE:
#   FRAME_TEMPLATE=ai/template-en bash ops/frame/frame-sync.sh --sync
# It is not "both in one run" because the fingerprint, the baseline and the version are each computed per
# template; mixed together, nothing can say which side matches which.
base_of() { if [ "$2" = consumer ]; then echo "$1"; else
  local t; t="${FRAME_TEMPLATE:-$(conf_get "$1" template)}"; echo "$1/${t:-ai/template}"; fi; }

# -- Classes: <mode>[@role] <glob>; **the last match wins** ----------------
# 【home= may be relative】Open-source users clone the source repo **next to their project**, so
# `home=../FRAME-Development-Model` is the least trouble (it survives moving to another machine).
# A relative path is resolved **against this project's root, not the current working directory** —
# otherwise running it from another directory says "cannot find the source FRAME repo", and the
# symptom says nothing about cwd.
home_resolve() { # home_resolve <home= from the conf>  -> the real path on this machine
  local p="$1" alt
  [ -n "$p" ] || { printf ''; return 0; }
  case "$p" in
    /*|[A-Za-z]:[\\/]*) ;;                                  # absolute: as written
    *) [ -d "$SRC/$p" ] && p="$(cd "$SRC/$p" && pwd)" ;;     # relative: to this project's root
  esac
  # 【One conf has to work on two machines】`home=` holds the real path on the Requester's machine
  # (a Windows `D:\…`). The same repo is mounted at a different path inside a cloud session.
  # **Do not edit the conf for that** (the conf is the truth as people see it); instead, when the
  # configured path does not exist, look for a mount point of the same name and say which one is used.
  if [ ! -d "$p" ]; then
    alt="$HOME/mnt/$(basename "$(printf '%s' "$p" | tr '\\' '/')")"
    [ -d "$alt" ] && { echo "ℹ️  home= from the conf does not exist on this machine; using the mount point of the same name: $alt" >&2; p="$alt"; }
  fi
  printf '%s' "$p"
}
class_of() { local p="$1" role="$2" m=seed mode pat mrole
  while read -r mode pat; do
    case "$mode" in ''|'#'*) continue;; esac
    [ -n "${pat:-}" ] || continue
    mrole=""; case "$mode" in *@*) mrole="${mode#*@}"; mode="${mode%@*}";; esac
    [ -n "$mrole" ] && [ "$mrole" != "$role" ] && continue
    if [ "$pat" = '**' ]; then m="$mode"; else case "$p" in $pat) m="$mode";; esac; fi
  done < "$CLASSES"
  echo "$m"; }

# 🔴 Content hash: strip CR first (a newline style is not a change)
h() { [ -f "$1" ] && tr -d '\r' < "$1" | sha256sum | cut -d' ' -f1 || echo "-"; }
hs() { tr -d '\r' < "$1" | sha256sum | cut -d' ' -f1; }   # for temporary files
# Keep the target's existing newline style when writing, so one sync does not turn a file into one big diff
cpn() { local s="$1" d="$2"
  if [ -f "$d" ] && head -c 4000 "$d" | grep -q $'\r'; then
    awk '{ sub(/\r$/,""); printf "%s\r\n", $0 }' "$s" > "$d"
  else cp "$s" "$d"; fi; }

# 🔴 **Never list a `.git` at any depth** (2026-09-27): one mis-run copied another project's repo,
# `.git` and all, into a template, so this listed 420 `.git/objects/...` files -- they entered the
# baseline, the distribution, and carried a private remote URL into a shipped artifact.
# A `.git` belongs to the repository, never to FRAME, so it is excluded HERE, at the listing layer,
# instead of once per call site (`-prune`, not `-not -path`: the latter still walks the whole tree).
# 🔴 **A consumer's FRAME sits at the repo root, so "list the files" must go by the MANIFEST, not by directory**
# (measured 2026-09-28). A consumer configured with `push=yes` ran `--sync` and reported
# "-> push out **100**" -- specs, the `src` skeleton, the requester's own words: **the whole project**.
# `find . -type f` on a consumer means "treat every file in this project as one of FRAME's", and together with
# "anything unclassified defaults to seed" and "present locally, absent upstream = push a skeleton" that adds up
# to pushing an entire project into the source repository.
# New criterion: **on a consumer side, list only what `ai/frame-manifest.txt` names AND that exists locally** --
# that manifest is the single source of truth for "which files FRAME itself has" (generated in the template by
# gen-frame-manifest.sh, class follow, so it travels with FRAME).
# 🔴 When the manifest is missing, list **nothing** (and say so on stderr): better a round that does nothing
# than one that treats an entire project as FRAME.
# This also fixes a performance problem with the same root: `fp_of` goes through here too, and walking a large
# repository once took 2m04s -- long enough that the version-stamping step was killed by an outer timeout and
# `ai/FRAME-VERSION` was left half written.
list_files() { local b mf; b="$(base_of "$1" "$2")"
  if [ "$2" = consumer ]; then
    mf="$1/ai/frame-manifest.txt"
    if [ ! -f "$mf" ]; then
      echo "⚠️  $1 has no ai/frame-manifest.txt (FRAME's own file list) -- **listing nothing**, so an entire project is never mistaken for FRAME. One distribution brings it in." >&2
      return 0
    fi
    ( cd "$b" 2>/dev/null || exit 0
      grep -vE '^[[:space:]]*(#|$)' "$mf" | tr -d '\r' | LC_ALL=C sort -u \
        | while IFS= read -r rel; do [ -f "$rel" ] && printf '%s\n' "$rel"; done )
    return 0
  fi
  (cd "$b" 2>/dev/null && find . -name .git -prune -o -type f -printf '%P\n' | LC_ALL=C sort); }
fp_of() { local R="$1" RO="$2" b rel
  b="$(base_of "$R" "$RO")"
  { while IFS= read -r rel; do
      [ "$(class_of "$rel" "$RO")" = follow ] || continue
      # 🔴 The version file itself stays out of the fingerprint: it *contains* the fingerprint, so including it
      # would bite its own tail (write it once -> the fingerprint changes -> the value just written is stale).
      # It is still a follow file and still syncs.
      [ "$rel" = "ai/FRAME-VERSION" ] && continue
      printf '%s  %s\n' "$(h "$b/$rel")" "$rel"
    done < <(list_files "$R" "$RO"); } | LC_ALL=C sort | sha256sum | cut -c1-16; }
ver_file() { echo "$(base_of "$1" "$2")/ai/FRAME-VERSION"; }
ver_read() { local f; f="$(ver_file "$1" "$2")"
  [ -f "$f" ] && grep -E '^version:' "$f" | head -1 | awk '{print $2}' || echo "0.0.0"; }
ver_write() { local R="$1" RO="$2" V="$3" FROM="$4" FFP="${5:-}" f; f="$(ver_file "$R" "$RO")"
  # 🔴 Three rules, every one of them measured:
  #  (1) `fingerprint` records **what this repo computes for itself**, never a copy of someone else's -- a
  #      consumer's set differs by construction (the role-qualified files are not follow for it), so a copied
  #      value makes the file lie, with no symptom; (2) hence `role`: **fingerprints compare only within a role**;
  #  (3) `synced_with` records **the repo name, not an absolute path** -- a cloud session mount path carries a
  #      session id that is meaningless once it ends, and it gets committed into a public repo (happened once).
  mkdir -p "$(dirname "$f")"
  { echo "version: $V"; echo "date: $(date +%F)"; echo "role: $RO"
    echo "fingerprint: $(fp_of "$R" "$RO")"
    [ -n "$FFP" ] && echo "source_fingerprint: $FFP"
    echo "synced_with: $(basename "$(printf '%s' "$FROM" | tr '\\' '/' | sed 's#/*$##')")"
    echo "# version is bumped by the Maintainer: structure/roles=major · rule semantics=minor · wording=patch"
    echo "# 🔴 The fingerprint is computed, never hand-edited, and **compares only with repos of the same role**;"
    echo "#    to know whether you kept up with the source, compare source_fingerprint with the source's own fingerprint."
  # 🔴 **Write a temp file and rename it** (measured 2026-09-28): `fp_of` takes two minutes on a large
  # repository, one distribution was killed by an outer timeout and `ai/FRAME-VERSION` was left with three
  # lines -- **a half-written version file is worse than none**: the next round reads a truncated version and
  # fingerprint. A rename is atomic: either the old file or the complete new one.
  } > "$f.tmp.$$" && mv -f "$f.tmp.$$" "$f" || { rm -f "$f.tmp.$$"; echo "🔴 cannot write $f; the old one is untouched." >&2; return 1; }; }

# 🔴 **Whether we may write upstream**: `push=` in `ai/frame-repo.conf`.
# An open-source user clones the FRAME source next to their project and **has no commit rights on it** --
# for them this mechanism can only **pull**. With `push=no`: pulling works as usual, and anything they changed
# locally is **reported, never written upstream** (writing it would only dirty their clone and make them think
# the change went upstream). **The test is whether they can actually push, not whether the script can write.**
#
# 🔴 **Why "yes here, no over there" needs no switch at all**: `ai/frame-repo.conf` is **one per repository**
# and sits on the **skip** list in `classes.txt` -- **a sync never touches it**. So the source maintainer's
# `push=yes` never travels out, an open-source user's `push=no` never travels back, and the sample shipped
# in the template already says `role=consumer` plus `push=no`.
# 🔴 **With no `push=` line, the role decides**: `consumer` defaults to **no**, `home`/`host` to **yes**.
# A default must make **the side that forgets it** safe: the template's most common reader has no commit
# rights, and the old "always default yes" would write upstream for them; the other way round, forgetting it
# only skips a push that the report still lists. An explicit value always wins over the default.
SROLE="$(role_of "$SRC")"
# 🔴 **Two gates, both bought with a real incident** (hit once on 2026-09-26, reverted, nothing lost):
# (1) `--apply` followed by a positional argument with no explicit `--dist` or `--sync`: **error, do not guess.**
#     Only a human knows whether that argument is "a target to distribute to" or "a source repo to reconcile with",
#     and guessing wrong pulls a consuming project's entire content into this repo's template (542 files, measured).
if [ "$SAW_APPLY" = 1 ] && [ "${#TARGETS[@]}" -gt 0 ] && [ "$SAW_DIST" != 1 ] && [ "$SAW_SYNC" != 1 ]; then
  echo "🔴 --apply was followed by \"${TARGETS[0]}\" without saying which side -- **not guessing**:"
  echo "   to **distribute** to it:  bash ops/frame/frame-sync.sh --dist --apply ${TARGETS[*]}"
  echo "   to reconcile with the **source repo**:  bash ops/frame/frame-sync.sh --sync --apply (the source comes from home= in ai/frame-repo.conf)"
  exit 2
fi

PUSH_OK="$(conf_get "$SRC" push)"
if [ -z "$PUSH_OK" ]; then
  if [ "$SROLE" = consumer ]; then PUSH_OK=no; else PUSH_OK=yes; fi
fi
# 🔴 **"May I push" and "should I touch these particular upstream things" are two different questions**
# (measured 2026-09-30 on a real consumer project). `push=` is about **permission** (do I have commit rights);
# the **root-file projection** and **upstream's version file** carry one more test -- **identity**: they are the
# source repository's own shop window, and only the side that CARRIES THE TEMPLATES (home/host) may generate them.
# What happened: a consumer with an explicit `push=yes` ran `--sync --apply` and **projected its OWN `README.md`
# into the source repo's root `README-zh_CN.md`**. Two roots:
#   (1) inside `roots_project`, `srcf="$SBASE/${tplrel#ai/template/}"` -- on a consumer **`$SBASE` IS the project
#       root**, so "the template's README" resolved to "this project's own README";
#   (2) both call sites tested `push=` only, never the role -- with `push=yes` it walked straight through to the write.
# Hence one shared criterion: **a consumer side never projects root files and never rewrites upstream's version file**
# (a one-way pull must touch neither). It judges **identity**, not permission.
UPSTREAM_OK=yes
[ "$PUSH_OK" = no ] && UPSTREAM_OK=no
[ "$SROLE" = consumer ] && UPSTREAM_OK=no
SBASE="$(base_of "$SRC" "$SROLE")"
[ -d "$SBASE" ] || { echo "🔴 this repo has no FRAME root: $SBASE"; exit 2; }

case "$MODE" in
  fingerprint) echo "$(fp_of "$SRC" "$SROLE")  version $(ver_read "$SRC" "$SROLE")"; exit 0;;
  status)
    echo "repo       : $SRC"
    echo "role       : $SROLE"
    echo "FRAME lives: ${SBASE#$SRC/} ($(list_files "$SRC" "$SROLE" | grep -c . ) files)"
    echo "version    : $(ver_read "$SRC" "$SROLE")   fingerprint $(fp_of "$SRC" "$SROLE")"
    echo "source repo: $(conf_get "$SRC" home)"
    echo "may push   : $PUSH_OK (push=no means pull-only, what an open-source user sets; with no push= line the role decides: consumer=no, home/host=yes)"
    exit 0;;
  diff)
    [ -n "$DIFF_T" ] && [ -n "$DIFF_P" ] || { echo "usage: --diff <repo> <relative path>"; exit 2; }
    diff -u "$(base_of "$DIFF_T" "$(role_of "$DIFF_T")")/$DIFF_P" "$SBASE/$DIFF_P" || true
    exit 0;;
esac

# 🔴 "Dirty" means **tracked files have been modified**, not "there are files not in git yet":
# untracked new files (for instance the conf and baseline this mechanism just created) cannot be clobbered by
# our writes -- what must hold is "do not tangle with someone's uncommitted changes", not "the working tree must
# be spotless". Counting untracked as dirty has a very concrete consequence: the files the mechanism itself
# creates would stop the mechanism from ever running.
git_dirty() { [ -d "$1/.git" ] || return 1
  [ -n "$(cd "$1" && git status --porcelain -- "${2:-.}" 2>/dev/null | grep -v '^??')" ]; }
# 🔴 What must hold is "**do not tangle with someone else's uncommitted changes**", not "the tree must be clean".
# The test: among the tracked, modified files, anything whose content equals the baseline entry is exactly what the
# last sync wrote -- that is ours, not someone else's.
# 【Why】The first sync is two steps (write the template, then project the root files); after step one the target is dirty,
# and a repo-wide check locks the second half out of its own repository (hit twice in practice).
foreign_dirty() { # foreign_dirty <repo> <baseline file (ignored, see below)> <the FRAME prefix in that repo>
  # 🔴 Deciding "did we write this" must look at **every baseline for this repo pair**, not just the current one:
  # one sync may run per template (Chinese, English), and what the first run wrote looks, to the second run,
  # like someone else's change -- measured: the English run reported all 21 files plus 4 root files the Chinese run had just pushed.
  local R="$1" _ignored="$2" PFX="$3" line st f rel cur out="" blf sfx pfx2 k
  [ -d "$R/.git" ] || return 1
  # 🔴 **Only look at paths FRAME actually manages** (2026-09-27). This used to read the target's WHOLE
  # git status, so any uncommitted business file in the target blocked distribution -- measured: one
  # consumer project had 375 uncommitted `ai/RandD/...` files the Researcher was working on, entirely
  # unrelated to what FRAME writes, and **distribution stalled on it two rounds in a row**.
  # What must hold is "**never overwrite a FRAME file someone else is editing**", not "the target
  # repository must be clean": FRAME only ever writes its own file list, and never touches the rest.
  # 🔴 The list is keyed by FRAME-RELATIVE path, and the repo's own template prefix is stripped when
  # comparing: the third argument equals the repo's ABSOLUTE path when FRAME sits at the repo root
  # (a consumer), not the empty string -- the first version pasted it in as a prefix, so every key was
  # an absolute path, nothing ever matched and **this check was effectively off for consumers**
  # (the reverse assertion caught it at once: a locally edited ai/rules/laws.md was not refused).
  # Prefixes come from the conf; nothing is guessed.
  declare -A OWNED=()
  while IFS= read -r rel; do [ -n "$rel" ] && OWNED["$rel"]=1; done < <(list_files "$SRC" "$SROLE")
  local -a TPFXS=(); local tp
  tp="$(conf_get "$R" template)";    [ -n "$tp" ] && TPFXS+=("$tp")
  tp="$(conf_get "$R" template_en)"; [ -n "$tp" ] && TPFXS+=("$tp")
  owned_path() { local q="$1" pp
    [ -n "${OWNED[$q]:-}" ] && return 0
    for pp in "${TPFXS[@]}"; do
      case "$q" in "$pp"/*) [ -n "${OWNED[${q#$pp/}]:-}" ] && return 0;; esac
    done
    return 1; }
  declare -A B=()
  for blf in "$SRC"/ops/frame/.baseline*; do
    [ -f "$blf" ] || continue
    sfx="${blf##*/.baseline}"                       # "" or "-template-en"
    # 🔴 The unsuffixed baseline belongs to the **default template** (`template=` in the conf), not to the current run --
    # computing its prefix from the current run makes every file the other run wrote mismatch, so it becomes "someone else's" (measured).
    if [ -n "$sfx" ]; then pfx2="ai/${sfx#-}"
    elif [ "$(role_of "$R")" = consumer ]; then pfx2=""
    else pfx2="$(conf_get "$R" template)"; pfx2="${pfx2:-ai/template}"; fi
    while read -r a b; do
      case "$a" in ''|'#'*) continue;; esac
      # 🔴 **One path may carry a different hash in several baselines** (root files are recorded in both):
      # "last one wins" makes **the freshly updated one mismatch**, so our own writes are judged someone else's (measured).
      # So store them as a **set**: matching any one of them means we wrote it.
      case "$b" in
        ROOT:*) k="${b#ROOT:}";;
        *) k="$pfx2/$b";;
      esac
      B["$k"]="${B[$k]:-} $a"
    done < "$blf"
  done
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    st="${line:0:2}"; f="${line:3}"
    case "$st" in '??') continue;; esac
    # 🔴 `ai/FRAME-VERSION` is written by this mechanism itself (the file says "never hand-edit"),
    # it is a seed file that never enters the baseline, so it cannot be recognized as ours; counting it as someone
    # else's would block the next sync, and hand-edits to it are pointless -- the next `--stamp` overwrites it.
    # 🔴 The same reasoning covers `ops/frame/.baseline*`: **they are this mechanism's own bookkeeping too**
    # (measured 2026-09-26: after the session path was stripped from the source baseline's header, this check
    # called it "someone else's uncommitted change" and refused to sync -- while that very edit existed to keep
    # a session path out of a public repository). The test is "do not get tangled in someone else's work", and
    # the mechanism's own bookkeeping is not someone else's work.
    case "$f" in */ai/FRAME-VERSION|ai/FRAME-VERSION) continue;; esac
    case "$f" in */ops/frame/.baseline*|ops/frame/.baseline*) continue;; esac
    f="${f%\"}"; f="${f#\"}"
    # Outside the list (business code, another seat's ledgers, the R&D line) FRAME never writes: not our business
    if ! owned_path "$f" && [ -z "${B[$f]:-}" ]; then continue; fi
    cur="$(h "$R/$f")"
    case " ${B[$f]:-} " in *" $cur "*) continue;; esac   # matches any baseline = written by us in some run
    out="$out $f"
  done < <(cd "$R" && git status --porcelain 2>/dev/null)
  [ -n "$out" ] && { echo "$out"; return 0; }
  return 1
}
git_untracked() { [ -d "$1/.git" ] || return 1
  [ -n "$(cd "$1" && git status --porcelain -- "${2:-.}" 2>/dev/null | grep '^??')" ]; }

# -- Root-file projection (map= / patch=): those files at the source repo root = the template plus declared patches --
# 🔴 **It is part of the same sync**, so it lives in a function called from both places: even when the fingerprints match, those files still have to be checked.
# 🔴 There is **no repo-wide dirty check here**, only a per-file look at whether that root file was hand-edited --
#    a repo-wide check would let the first half of one sync (the template just written) lock out its second half (measured).
roots_project() { # roots_project <source FRAME repo> <write or not>
  local HR="$1" DOIT="$2" mline rootf tplrel srcf proj pl expr before n=0 fail=0 dirtyf
  # 🔴 Second line of defence (both call sites already gate on UPSTREAM_OK): **a consumer never projects root files.**
  # It lives inside the function so a future call site cannot miss it again -- this defect came precisely from
  # "two call sites, each testing it separately".
  [ "$SROLE" = consumer ] && return 0
  [ "$PUSH_OK" = no ] && return 0
  # -- The source repo's root files are projected in the same run --
  # 【Why not on the distribution side】That needs a second command, by which time this step has made the source dirty,
  # so iron rule 2 would lock it out of its own repo (measured). **One sync should leave both sides in place.**
  
  while IFS= read -r mline; do
    [ -n "$mline" ] || continue
    rootf="${mline%%:*}"; tplrel="${mline#*:}"; srcf="$SBASE/${tplrel#ai/template/}"
    [ -f "$SRC/$tplrel" ] && srcf="$SRC/$tplrel"
    [ -f "$srcf" ] || { echo "  🔴 the map source does not exist: $tplrel"; fail=$((fail+1)); continue; }
    proj="$(mktemp)"; cp "$srcf" "$proj"
    while IFS= read -r pl; do
      [ -n "$pl" ] || continue
      [ "${pl%%:*}" = "$rootf" ] || continue
      expr="${pl#*:}"; before="$(hs "$proj")"
      sed -i "$expr" "$proj" 2>/dev/null || true
      [ "$(hs "$proj")" = "$before" ] && { fail=$((fail+1))
        echo "  🔴 patch did not apply (did the source reword it?): $rootf  ${expr:0:44}"; }
    done < <(conf_all "$HR" patch)
    if [ "$(hs "$proj")" != "$(h "$HR/$rootf")" ]; then
      if [ -d "$HR/.git" ] && [ -n "$(cd "$HR" && git status --porcelain -- "$rootf" 2>/dev/null | grep -v '^??')" ]; then
        echo "  🔴 $rootf was hand-edited (uncommitted) -- reported, not written: hand-edits always conflict on the next sync"; fail=$((fail+1)); rm -f "$proj"; continue
      fi
      [ "$DOIT" = 1 ] && cpn "$proj" "$HR/$rootf"; n=$((n+1)); echo "    ~ root file $rootf  <- $tplrel"
    fi
    rm -f "$proj"
  done < <(conf_all "$HR" map)
  [ $((n+fail)) -gt 0 ] && printf '  root files: updated %s  patches that did not apply %s\n' $n $fail
  return 0
}


# == Two-way sync (the command word "sync FRAME") =========================
# == Report the classes only (for the guards) =============================
# 🔴 **A class has exactly one source of truth**: `classes.txt` is interpreted by this script, and any
#    other script that needs a class asks this one. **It must not copy the glob matching**: a copy is a
#    second set of criteria, and when `classes.txt` changes only one of them follows -- with **no symptom
#    at all** (that is where the "single source of truth" rows in `layout.md`'s budget table came from).
# One line per file: `<class><TAB><path relative to the template>`.
if [ "$MODE" = classify ]; then
  while IFS= read -r rel; do printf '%s\t%s\n' "$(class_of "$rel" "$SROLE")" "$rel"; done < <(list_files "$SRC" "$SROLE")
  exit 0
fi

# == Stamp the version (step 8 of the ten) ================================
# 🔴 **People bump the version, the machine computes the fingerprint**: this command writes the same version
# into ai/FRAME-VERSION on both sides, each with its freshly computed fingerprint (they should match).
# The version file itself is outside the fingerprint, so stamping does not change it.
if [ "$MODE" = stamp ]; then
  [ -n "$STAMP_V" ] || { echo "usage: --stamp <version> (structure/roles=major · rule semantics=minor · wording=patch)"; exit 2; }
  HOME_REPO="$(home_resolve "${TARGETS[0]:-$(conf_get "$SRC" home)}")"
  [ -d "$HOME_REPO" ] || { echo "🔴 cannot find the source FRAME repo"; exit 2; }
  HROLE="$(role_of "$HOME_REPO")"
  ver_write "$SRC" "$SROLE" "$STAMP_V" "$(conf_get "$SRC" home)" "$(fp_of "$HOME_REPO" "$HROLE")"
  # Upstream's version file is not ours to touch: `push=no` is permission, `consumer` is identity (see UPSTREAM_OK).
  # 🔴 Measured 2026-09-30: a consumer with `push=yes` ran `--stamp` and **rewrote the source repo's
  # ai/FRAME-VERSION** -- the one-way-pull side stamps "which version I follow", not "what this version is".
  [ "$UPSTREAM_OK" = yes ] && ver_write "$HOME_REPO" "$HROLE" "$STAMP_V" "$SRC" "$(fp_of "$SRC" "$SROLE")"
  # 🔴 **Only say what was actually done**: with push=no the upstream file was not stamped, and
  # saying "both sides stamped" is a lie the reader then acts on, believing the source is in order.
  if [ "$UPSTREAM_OK" != yes ]; then
    echo "✅ stamped $STAMP_V here ($([ "$SROLE" = consumer ] && echo "consumer: one-way pull" || echo "push=no"); upstream's version file untouched): fingerprint $(fp_of "$SRC" "$SROLE")"
    echo "   source_fingerprint holds the source's current fingerprint $(fp_of "$HOME_REPO" "$HROLE")"
  else
    echo "✅ both sides stamped $STAMP_V: this project $(fp_of "$SRC" "$SROLE")   source $(fp_of "$HOME_REPO" "$HROLE")"
  fi
  # A consumer has no template directory, so that line comes out empty for it (measured)
  [ "$SROLE" = consumer ] || echo "   (template: ${FRAME_TEMPLATE:-$(conf_get "$SRC" template)}; the other template needs its own run)"
  exit 0
fi

# 🔴 `--adopt` defaults to the **two-way reconciliation** side; to lay a baseline in another project you must say
# `--dist --adopt <target>` explicitly. (Without this switch, `--adopt <target>` was read as "treat this target as the
# source", and the baseline went into this repo while the target got nothing.)
if [ "$DIST" != 1 ] && { [ "$MODE" = sync ] || [ "$MODE" = adopt ]; }; then
  HOME_REPO="$(home_resolve "${TARGETS[0]:-$(conf_get "$SRC" home)}")"
  [ -n "$HOME_REPO" ] && [ -d "$HOME_REPO" ] || { echo "🔴 cannot find the source FRAME repo (home= in ai/frame-repo.conf, or pass one on the command line)"; exit 2; }
  HROLE="$(role_of "$HOME_REPO")"; HBASE="$(base_of "$HOME_REPO" "$HROLE")"
  # 🔴 (2) **The other end of a reconcile must be home or host**: a consumer is a **distribution target**, not a
  # source. Measured: `--apply ../<a consuming project>` reconciled against it as if it were the source and
  # "pulled in 542 / pushed out 2", writing that project's own content (`ai/specs/*`, `product/requirements/*`,
  # `src/*`) into this repo's `ai/template/`. The test is **"is this end entitled to be the source"**, not "does
  # the path exist".
  case "$HROLE" in
    home|host) ;;
    *) echo "🔴 Refused: $HOME_REPO has role ${HROLE:-(no ai/frame-repo.conf)}, so **it is not a source repository**."
       echo "   A consumer is a distribution target: to distribute, run  bash ops/frame/frame-sync.sh --dist --apply $HOME_REPO"
       echo "   To reconcile with the real source, pass no positional argument (the source comes from home= in ai/frame-repo.conf)."
       exit 2;;
  esac
  SFP="$(fp_of "$SRC" "$SROLE")"; HFP="$(fp_of "$HOME_REPO" "$HROLE")"
  echo "this project: $SRC   role $SROLE   version $(ver_read "$SRC" "$SROLE")   fingerprint $SFP"
  echo "source FRAME: $HOME_REPO   role $HROLE   version $(ver_read "$HOME_REPO" "$HROLE")   fingerprint $HFP"
  # Even with equal fingerprints, check the root files (they are outside the fingerprint but part of this FRAME)
  if [ "$SFP" = "$HFP" ] && [ "$MODE" = sync ]; then
    [ "$UPSTREAM_OK" = yes ] && roots_project "$HOME_REPO" "$APPLY"
    echo "✅ identical fingerprints -- already the same FRAME; nothing to sync (not one file touched)."; exit 0; fi

# 🔴 **One baseline per template**: the two templates use identical relative paths (`ai/rules/laws.md` exists in
# both), so sharing one baseline reads "the other template's content" as "someone changed this one" -- 22 false
# conflicts in practice.
  BLSFX=""; [ -n "${FRAME_TEMPLATE:-}" ] && BLSFX="-$(basename "$FRAME_TEMPLATE")"
  BL="$SRC/ops/frame/.baseline$BLSFX"
  declare -A BASE=()
  [ -f "$BL" ] && while read -r a b; do case "$a" in ''|'#'*) continue;; *) BASE["$b"]="$a";; esac; done < "$BL"

  PULL=(); PUSH=(); CONF=(); GONE=(); SAME=0; SEEDN=0; SKIPN=0; UNK=0; LOCALN=0; SEEDDIFF=()
  TMPBL="$(mktemp)"
  ALL="$( { list_files "$SRC" "$SROLE"; list_files "$HOME_REPO" "$HROLE"; } | LC_ALL=C sort -u )"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    cs="$(class_of "$rel" "$SROLE")"; ch="$(class_of "$rel" "$HROLE")"
    if [ "$cs" = skip ] || [ "$ch" = skip ]; then SKIPN=$((SKIPN+1)); continue; fi
    sh="$(h "$SBASE/$rel")"; hh="$(h "$HBASE/$rel")"; bh="${BASE[$rel]:--}"
    if [ "$sh" = "$hh" ]; then SAME=$((SAME+1)); echo "$sh $rel" >> "$TMPBL"; continue; fi
    # 🔴 **Present locally, absent upstream = this project's own thing, and it is NEVER pushed**
    # (only the `push=no` branch used to catch this). Measured 2026-09-28: a consumer with `push=yes`
    # never reached this line, fell through to the seed branch's "present locally, absent upstream ->
    # push a skeleton", and **100 project files were listed as skeletons to push to the source**.
    # "Pushing a skeleton" only makes sense **between two templates (host <-> home)**: there, a missing
    # file really is a missing file. Every extra file on a consumer is that project's own content, and
    # pushing it means pouring the project into FRAME.
    # So the criterion is the **role**, not `push=`: whether you CAN push is permission,
    # whether you SHOULD is identity.
    if { [ "$PUSH_OK" = no ] || [ "$SROLE" = consumer ] || [ "$HROLE" = consumer ]; } \
       && [ "$hh" = "-" ] && [ "$sh" != "-" ]; then
      LOCALN=$((LOCALN+1)); echo "$sh $rel" >> "$TMPBL"; continue; fi
    # 🔴 seed files never take part in two-way overwriting: a project fills them in, and pushing them back would carry project content into FRAME
    if [ "$cs" = seed ] || [ "$ch" = seed ]; then
      if   [ "$sh" = "-" ]; then PULL+=("$rel  (skeleton, created)")
      # 🔴 Second line of defence (the role check above already caught it): **only two templates push skeletons**
      elif [ "$hh" = "-" ] && [ "$SROLE" != consumer ] && [ "$HROLE" != consumer ]; then
        PUSH+=("$rel  (skeleton, created)")
      else SEEDN=$((SEEDN+1)); [ "$bh" != "-" ] && echo "$bh $rel" >> "$TMPBL"
        # 🔴 **When both sides are templates, "each keeps its own" hides a fork between the two blanks**
        # (measured 2026-09-27): seed exists to protect content a PROJECT filled in, and between two
        # templates there is no project content -- so both BLANKS get edited and the mechanism says nothing.
        # Measured: the source copy of the entry file had lost two rows (the advisor trigger and the
        # "sync FRAME" command row) that this project's copy still had, and each side believed it was right.
        # This only REPORTS (seed still never overwrites); a human decides which way to merge.
        # ai/FRAME-VERSION is exempt: those two are supposed to differ (role, fingerprint, source_fingerprint).
        if [ "$SROLE" != consumer ] && [ "$HROLE" != consumer ] && [ "$rel" != ai/FRAME-VERSION ]; then
          SEEDDIFF+=("$rel"); fi
      fi
      continue; fi
    # 🔴 **adopt has to say which side is the truth**: a baseline means "the content both sides last agreed on".
    # Record the source's ⇒ every local difference counts as **mine**, pushed out next run (the usual first sync);
    # record this project's (--adopt-mine) ⇒ differences count as **theirs**, pulled in next run.
    # The first version always recorded this project's hash, so "I am newer than the source" was read as
    # "the source changed", and **the next run would pull the older copies back over the newer ones**.
    # What must hold is the direction, not that a line got written.
    if [ "$MODE" = adopt ]; then
      if [ "$ADOPT_MINE" = 1 ]; then [ "$sh" != "-" ] && echo "$sh $rel" >> "$TMPBL"
      else [ "$hh" != "-" ] && echo "$hh $rel" >> "$TMPBL"; fi
      SAME=$((SAME+1)); continue; fi
    # 🔴 "not there" is two different things: **never existed** (new) and **was in the baseline and is gone now** (deleted).
    # Getting this wrong is asymmetric: treat a deletion as a new file and you push back what the other side just
    # deleted -- **resurrecting it on every sync**, so nobody can ever delete anything. Iron rule 4: only report.
    if   [ "$sh" = "-" ] && [ "$bh" != "-" ]; then GONE+=("$rel  (this project deleted it, the source still has it -- reported, never deleted automatically)")
    elif [ "$hh" = "-" ] && [ "$bh" != "-" ]; then GONE+=("$rel  (the source deleted it, this project still has it -- reported, never deleted automatically)")
    elif [ "$sh" = "-" ]; then PULL+=("$rel  (new in source)")
    elif [ "$hh" = "-" ]; then PUSH+=("$rel  (new in this project)")
    elif [ "$bh" = "-" ]; then UNK=$((UNK+1)); CONF+=("$rel  (no baseline: cannot tell who changed it)"); echo "$sh $rel" >> "$TMPBL"
    elif [ "$sh" = "$bh" ]; then PULL+=("$rel")
    elif [ "$hh" = "$bh" ]; then PUSH+=("$rel")
    else CONF+=("$rel  🔴 both sides changed it"); echo "$sh $rel" >> "$TMPBL"; fi
  done <<< "$ALL"

  echo "──────────────────────────────────────────"
  printf '  <- pull in %-4s  -> push out %-4s  same %-4s  seed kept as-is %-4s  skipped %-4s\n' ${#PULL[@]} ${#PUSH[@]} $SAME $SEEDN $SKIPN
  if [ "${#SEEDDIFF[@]}" -gt 0 ]; then
    echo "  🔶 the two templates' seed skeletons differ (${#SEEDDIFF[@]}) -- the mechanism will not merge these, a human must look:"
    for sd in "${SEEDDIFF[@]}"; do echo "     $sd"; done
    echo "     seed protects content a PROJECT filled in, and both of these sides are templates: a fork left alone only grows."
  fi
  printf '  🔴 needs a human %-4s (of which %s are "no baseline")\n' ${#CONF[@]} $UNK
  [ "$LOCALN" -gt 0 ] && echo "  $LOCALN files are this project's own (upstream has none of them; with push=no they are left alone)"
  [ ${#PULL[@]} -gt 0 ] && { echo "  -- <- pull in --"; printf '    %s\n' "${PULL[@]}" | head -30; }
  if [ ${#PUSH[@]} -gt 0 ]; then
    if [ "$PUSH_OK" = no ]; then
      echo "  -- 🔶 changed locally (**not pushed upstream**; you have no commit rights on the source) --"; printf '    %s\n' "${PUSH[@]}" | head -30
      echo "    Three ways: (1) keep it as a local fork (reported like this every round; the baseline records **upstream's**"
      echo "                    copy, so your fork is never silently overwritten -- and if upstream later changes the same"
      echo "                    file, it becomes a 🔴 needs-a-human conflict)"
      echo "                (2) drop your version and take upstream's (delete yours here and run again to pull it back)"
      echo "                (3) want it upstream: open an issue / PR on the source repo (this mechanism will not push for you)"
    else
      echo "  -- -> push out --"; printf '    %s\n' "${PUSH[@]}" | head -30
    fi
  fi
  [ ${#GONE[@]} -gt 0 ] && { echo "  -- one side deleted it (🔴 never deleted automatically; confirm yourself) --"; printf '    ? %s\n' "${GONE[@]}" | head -20; }
  [ ${#CONF[@]} -gt 0 ] && { echo "  -- 🔴 needs a human (reported, nothing written) --"; printf '    ! %s\n' "${CONF[@]}" | head -30
    echo "    see the difference: bash ops/frame/frame-sync.sh --diff \"$HOME_REPO\" <path from above>"; }
  if [ ${#PUSH[@]} -eq 0 ] && [ ${#CONF[@]} -eq 0 ] && [ ${#PULL[@]} -gt 0 ]; then
    echo "  ℹ️  this project has not changed FRAME -- so this run is simply **a one-way pull from the source** (version number included)."; fi
  # 🔴 Say "nothing to do" out loud too: differing fingerprints do not mean being behind -- this
  # project's own files always keep the fingerprints apart, and that is not a difference. Without
  # this line a consumer sees "fingerprints differ" every round and assumes they are behind.
  if [ ${#PULL[@]} -eq 0 ] && [ ${#PUSH[@]} -eq 0 ] && [ ${#CONF[@]} -eq 0 ] && [ ${#GONE[@]} -eq 0 ]; then
    echo "  ✅ in line with upstream -- nothing to sync (this project's own files are not a difference; they are why the fingerprints differ)."; fi

  if [ "$MODE" = adopt ]; then
    mkdir -p "$(dirname "$BL")"
# 🔴 **The baseline header records the repository's name, never an absolute path**: a cloud session's mount path
# carries a session id that means nothing once it ends, and this file gets committed into a **public repository**
# (the same lesson as `synced_with`, which leaked once).
    { echo "# adopt: taking what both sides look like now as the baseline  $(date +%F)  source=$(basename "$HOME_REPO")"
      echo "# one line each: <content sha256> <relative path>. 🔴 adopt accepts the current state as correct -- look before you adopt."
      LC_ALL=C sort -u "$TMPBL"; } > "$BL"
    echo "  ✅ baseline recorded: ${BL#$SRC/} ($(grep -vc '^#' "$BL") entries)"
    rm -f "$TMPBL"; exit 0; fi

  if [ "$APPLY" != 1 ]; then
    echo "  (this is a report; nothing was written. To write: --sync --apply. First baseline: --adopt)"
    rm -f "$TMPBL"; [ ${#CONF[@]} -gt 0 ] && exit 1; exit 0; fi

  # -- iron rules 1 and 2: both sides must be clean --
  # 🔴 A consumer's FRAME sits at the project root, so `${SBASE#$SRC/}` becomes the whole repo -- and **any seat's uncommitted
  #    business file** (bug reports, mail, memory...) blocks the sync (measured in a consumer project, 2026-09-30: 8 files the Reviewer / Supervisor seats were
  #    writing blocked a pure pull). What is kept is "only committed **FRAME** counts": a consumer looks only at the manifest's follow-class files
  #    (the only ones a sync writes).
  if [ "$SROLE" = consumer ]; then
    FFOL=(); while IFS= read -r r; do [ "$(class_of "$r" consumer)" = follow ] && FFOL+=("$r"); done < <(list_files "$SRC" consumer)
    SDIRTY="$( [ "${#FFOL[@]}" -gt 0 ] && cd "$SRC" && git status --porcelain -- "${FFOL[@]}" 2>/dev/null | grep -v '^??')"
  else
    SDIRTY="$(git_dirty "$SRC" "${SBASE#$SRC/}" && echo dirty)"
  fi
  if [ -n "$SDIRTY" ]; then
    echo "🔴 this project has uncommitted FRAME changes -- refusing to write. **Only committed FRAME counts**; commit first."; [ "$SROLE" = consumer ] && printf '%s\n' "$SDIRTY" | head -10 | sed 's/^/     /'; rm -f "$TMPBL"; exit 1; fi
  # 🔴 Judge the source repo's dirt against **this project's baseline**: it holds "the content both sides last
  #    agreed on", so anything in the source matching it is exactly what the last sync wrote. The source's own
  #    distribution baseline would judge it wrong (that one records what the target looked like *before* a push).
  FOREIGN=""
  [ "$PUSH_OK" = no ] || FOREIGN="$(foreign_dirty "$HOME_REPO" "$BL" "${HBASE#$HOME_REPO/}" || true)"
  if [ -n "$FOREIGN" ]; then
    echo "🔴 the source repo has **someone else's** uncommitted changes -- refusing to write:$FOREIGN"; rm -f "$TMPBL"; exit 1; fi
  # -- iron rule: with conflicts, nothing is written --
  if [ ${#CONF[@]} -gt 0 ]; then
    echo "🔴 ${#CONF[@]} entries need a human, so **nothing is written**. Say \"sync FRAME\" again once they are handled."; rm -f "$TMPBL"; exit 1; fi

  for e in "${PULL[@]}"; do rel="${e%%  (*}"; rel="${rel% }"
    mkdir -p "$(dirname "$SBASE/$rel")"; cpn "$HBASE/$rel" "$SBASE/$rel"; done
  if [ "$PUSH_OK" = no ]; then
    [ ${#PUSH[@]} -gt 0 ] && echo "  🔶 ${#PUSH[@]} local changes were **not pushed upstream** (push=no) -- see the three ways above"
  else
    for e in "${PUSH[@]}"; do rel="${e%%  (*}"; rel="${rel% }"
      mkdir -p "$(dirname "$HBASE/$rel")"; cpn "$SBASE/$rel" "$HBASE/$rel"; done
  fi
  if [ "$PUSH_OK" = no ]; then
    echo "  ✅ written: pulled in ${#PULL[@]} · pushed out 0 (push=no: not one byte went upstream)"
  else
    echo "  ✅ written: pulled in ${#PULL[@]} · pushed out ${#PUSH[@]} (🔴 never deletes: a file dropped in the source is only reported above)"
  fi
  # 🔴 Projecting root files writes upstream, so push=no skips it (that is the source maintainer's job)
  [ "$UPSTREAM_OK" = yes ] && roots_project "$HOME_REPO" 1
  NFP="$(fp_of "$SRC" "$SROLE")"; NHFP="$(fp_of "$HOME_REPO" "$HROLE")"
  echo "  fingerprints recomputed: this project $NFP   source $NHFP"
  if [ "$PUSH_OK" = no ]; then
    # 🔴 With push=no the fingerprints **cannot** become equal (local forks + seed files kept as-is),
    # so do not print that as a warning: a warning that lights up every round stops being read.
    [ "$NFP" = "$NHFP" ] || echo "  ℹ️ differing fingerprints are normal here: with push=no, local forks and seed files keep the two sides apart."
    echo "  next (for a human): --stamp <the source's version> (push=no writes only this project's file) -> one maintenance-log line ->"
    echo "                      bash ops/verify/check-all.sh -> tell the AI \"reload the rules\"."
  else
    [ "$NFP" = "$NHFP" ] || echo "  ⚠️ the fingerprints still differ -- usually seed files kept as-is (normal), or a difference nobody handled."
    echo "  next (for a human): bump the version -> write ai/FRAME-VERSION on both sides -> one maintenance-log line each -> commit the source repo and push it to GitHub."
  fi
  # Iron rule 5: re-record the baseline
  { echo "# re-recorded after apply  $(date +%F)  source=$(basename "$HOME_REPO")"
    # 🔴 Root files go into the baseline too: without them the next run has nothing to judge "who changed these"
    # against, and since this run just projected them, it would read them as someone else's (measured).
    while IFS= read -r mline; do
      [ -n "$mline" ] || continue
      rootf="${mline%%:*}"
      printf '%s ROOT:%s\n' "$(h "$HOME_REPO/$rootf")" "$rootf"
    done < <(conf_all "$HOME_REPO" map)
    while IFS= read -r rel; do [ -n "$rel" ] || continue
      cs="$(class_of "$rel" "$SROLE")"; [ "$cs" = skip ] && continue
      # 🔴 A local fork under push=no: the baseline records **upstream's** copy, not yours.
      # Record yours and the next round judges upstream's original as "the source changed it", so the
      # **next --apply silently overwrites your fork** (measured in a sandbox). With upstream's copy
      # recorded, the fork is reported 🔶 every round and never touched; and once upstream changes the
      # same file too, it becomes a real "both sides changed" conflict for a human.
      hhb="$(h "$HBASE/$rel")"; shb="$(h "$SBASE/$rel")"
      if [ "$PUSH_OK" = no ] && [ "$hhb" != "-" ] && [ "$shb" != "$hhb" ]; then
        printf '%s %s\n' "$hhb" "$rel"
      else printf '%s %s\n' "$shb" "$rel"; fi
    done <<< "$ALL"; } > "$BL"
  echo "  ✅ baseline re-recorded: ${BL#$SRC/}"
  rm -f "$TMPBL"; exit 0
fi

# == Distribute to other projects (home/host) =============================
if [ ${#TARGETS[@]} -eq 0 ] && [ -f "$SRC/ops/frame/targets.txt" ]; then
  while IFS= read -r l; do case "$l" in ''|'#'*) ;; *) TARGETS+=("$l");; esac; done < "$SRC/ops/frame/targets.txt"; fi
[ ${#TARGETS[@]} -gt 0 ] || { echo "no targets: pass a path, or list them in ops/frame/targets.txt (one per line)"; exit 2; }
if [ "$APPLY" = 1 ] && git_dirty "$SRC" "${SBASE#$SRC/}"; then
  echo "🔴 this project has uncommitted FRAME changes -- refusing to distribute. **Only committed FRAME counts**."; exit 1; fi
rc=0
for T in "${TARGETS[@]}"; do
  [ -d "$T" ] || { echo "🔴 target does not exist: $T"; rc=1; continue; }
  TROLE="$(role_of "$T")"; TBASE="$(base_of "$T" "$TROLE")"
  BLSFX=""; [ -n "${FRAME_TEMPLATE:-}" ] && BLSFX="-$(basename "$FRAME_TEMPLATE")"
  BL="$T/ops/frame/.baseline$BLSFX"
  echo "══════════════════════════════════════════════"
  echo "target: $T   role: $TROLE   FRAME lands in: ${TBASE#$T/}"
  # 🔴 Same reasoning as the source side (fixed there twice): the test is "**are there someone else's
  #    uncommitted changes**", not "is the tree clean". What the last distribution wrote is in the baseline,
  #    so it is not someone else's -- a repo-wide check deadlocks: write -> guards red -> commit refused ->
  #    the next distribution blocked by "dirty".
  # 🔴 **The block moves from "the whole repository" down to "the one file this round is about to write"**
  # (measured 2026-09-28). The previous version had already narrowed the scope to "inside FRAME's list",
  # but it was still an all-or-nothing veto: of the 14 files one refused distribution listed,
  # **5 had been hand-aligned and were byte-identical to the template** (distribution judges them "same" and
  # never writes them), **8 were seed or project-owned** (ledgers, mailboxes, the profile -- distribution never
  # writes a seed that already exists), and **the number that would actually be written AND was dirty: 0**.
  # A perfectly legal distribution was blocked outright.
  # New criterion: check a file's own dirtiness only when **about to overwrite that file**; report that one and
  # write the rest. One `git status` here (per-file git calls are far too slow) builds the "tracked and modified" set.
  # 🔴 The prefix must be the FRAME-RELATIVE one: on a consumer `TBASE` IS the repo root, so `${TBASE#$T/}`
  # strips nothing and leaves an absolute path (the same trap as in foreign_dirty above).
  TPFX="${TBASE#$T/}"; case "$TPFX" in /*) TPFX="";; esac; [ "$TPFX" = "$T" ] && TPFX=""
  declare -A TDIRTY=()
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "${line:0:2}" in '??') continue;; esac
    tdf="${line:3}"; tdf="${tdf%\"}"; tdf="${tdf#\"}"
    TDIRTY["$tdf"]=1
  done < <(cd "$T" && git status --porcelain 2>/dev/null)
  NONF=${#TDIRTY[@]}
  if [ "$APPLY" = 1 ] && [ "$NONF" -gt 0 ]; then
    echo "  🔶 the target has $NONF uncommitted changes (only the ones this round would actually overwrite are held back; the rest are written) -- commit them per seat."; fi
  declare -A TB=()
  [ -f "$BL" ] && while read -r a b; do case "$a" in ''|'#'*) continue;; *) TB["$b"]="$a";; esac; done < "$BL"
  nC=0; nU=0; nS=0; nSeed=0; nSkip=0; nConf=0; nGone=0; C=(); U=(); K=(); G=()
  TMP="$(mktemp)"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    cls="$(class_of "$rel" "$TROLE")"
    [ "$cls" = skip ] && { nSkip=$((nSkip+1)); continue; }
    s="$SBASE/$rel"; t="$TBASE/$rel"; sh="$(h "$s")"; th="$(h "$t")"; bh="${TB[$rel]:--}"
    if [ "$th" = "-" ]; then nC=$((nC+1)); C+=("$rel")
      [ "$APPLY" = 1 ] && { mkdir -p "$(dirname "$t")"; cpn "$s" "$t"; }
      echo "$sh $rel" >> "$TMP"; continue; fi
    if [ "$sh" = "$th" ]; then nS=$((nS+1)); echo "$sh $rel" >> "$TMP"; continue; fi
    if [ "$cls" = seed ]; then nSeed=$((nSeed+1)); echo "$bh $rel" >> "$TMP"; continue; fi
    # 🔴 Same reasoning as in the sync branch: **whose hash the baseline records decides whose the differences are**.
    # On the distribution side, adopt means "**accept the target as it is now**", so record the **target's** hash --
    # next run th == bh, and a changed source overwrites normally. Recording the source's would turn every file
    # into a false "the target changed it" conflict.
    if [ "$MODE" = adopt ]; then
      if [ "$ADOPT_MINE" = 1 ]; then echo "$sh $rel" >> "$TMP"
      else [ "$th" != "-" ] && echo "$th $rel" >> "$TMP"; fi
      nS=$((nS+1)); continue; fi
    if [ "$bh" = "-" ]; then nConf=$((nConf+1)); K+=("$rel  (no baseline)"); echo "$th $rel" >> "$TMP"
    elif [ "$th" = "$bh" ]; then
      # 🔴 **Only at the point of actually overwriting it do we look at its own uncommitted changes** (see above).
      if [ -n "${TDIRTY[${TPFX:+$TPFX/}$rel]:-}" ]; then
        nConf=$((nConf+1)); K+=("$rel  (target has uncommitted changes; not written this round)"); echo "$bh $rel" >> "$TMP"
      else
        nU=$((nU+1)); U+=("$rel")
        [ "$APPLY" = 1 ] && cpn "$s" "$t"; echo "$sh $rel" >> "$TMP"
      fi
    else nConf=$((nConf+1)); K+=("$rel  (target changed it)")
      # 🔴 **For a conflicting file the baseline keeps "the content both sides last agreed on"; it does NOT
      # record the target's current hash** (2026-09-28). Recording the target's hash has a very concrete
      # consequence: next round, if the target leaves the file alone, `th == bh` is judged "update" and
      # **the template overwrites what the target changed, without a word** -- measured: a project's
      # hand-merged self-check list came within one round of being wiped (the supervisor had to hand-edit
      # that baseline line back to the template's hash to hold it off).
      # Keeping the old baseline means the file is reported as "target changed" **every round** until a human
      # really deals with it; once they align it with the template, the first criterion (`sh == th`) judges it
      # "same" and the report disappears by itself.
      echo "$bh $rel" >> "$TMP"; fi
  done < <(list_files "$SRC" "$SROLE")

  # -- Root-file mapping map= / patch=: those files are "the template plus declared, repo-specific patches" --
  nMap=0; nMapSame=0; nMapConf=0; nPatchFail=0; M=(); MC=()
  while IFS= read -r mline; do
    [ -n "$mline" ] || continue
    rootf="${mline%%:*}"; tplrel="${mline#*:}"; srcf="$SRC/$tplrel"
    [ -f "$srcf" ] || { echo "  🔴 the map source does not exist: $tplrel"; rc=1; continue; }
    proj="$(mktemp)"; cp "$srcf" "$proj"
    while IFS= read -r pl; do
      [ -n "$pl" ] || continue
      [ "${pl%%:*}" = "$rootf" ] || continue
      expr="${pl#*:}"; before="$(hs "$proj")"
      sed -i "$expr" "$proj" 2>/dev/null || true
      [ "$(hs "$proj")" = "$before" ] && { nPatchFail=$((nPatchFail+1))
        MC+=("$rootf  🔴 patch did not apply (did the source reword it? this patch needs updating): ${expr:0:44}"); }
    done < <(conf_all "$T" patch)
    ph="$(hs "$proj")"; th="$(h "$T/$rootf")"; bh="${TB[ROOT:$rootf]:--}"
    if [ "$ph" = "$th" ]; then nMapSame=$((nMapSame+1)); echo "$ph ROOT:$rootf" >> "$TMP"
    elif [ "$MODE" = adopt ]; then
      # 🔴 Same reasoning as above: adopt records **the target as it is now**, so that next run th == bh and the
      # update flows in normally. Recording the projected content turns every root file into a false conflict.
      nMapSame=$((nMapSame+1)); echo "$th ROOT:$rootf" >> "$TMP"
    elif [ "$th" = "-" ] || [ "$th" = "$bh" ]; then
      nMap=$((nMap+1)); M+=("$rootf  ← $tplrel")
      [ "$APPLY" = 1 ] && cpn "$proj" "$T/$rootf"
      echo "$ph ROOT:$rootf" >> "$TMP"
    else nMapConf=$((nMapConf+1)); MC+=("$rootf  (target changed it, or there is no baseline)"); echo "$th ROOT:$rootf" >> "$TMP"; fi
    rm -f "$proj"
  done < <(conf_all "$T" map)

  # Iron rule 4: a file dropped in the source is only reported
  if [ -f "$BL" ]; then
    while read -r a b; do case "$a" in ''|'#'*) continue;; esac
      case "$b" in ROOT:*) continue;; esac
      [ -f "$SBASE/$b" ] || { nGone=$((nGone+1)); G+=("$b"); }
    done < "$BL"; fi

  printf '  created %-4s updated %-4s same %-4s kept (seed) %-4s skipped %-4s\n' $nC $nU $nS $nSeed $nSkip
  printf '  🔴 needs a human %-4s dropped in source %-4s  root mapping: updated %s same %s needs a human %s patches that did not apply %s\n' $nConf $nGone $nMap $nMapSame $nMapConf $nPatchFail
  [ ${#C[@]} -gt 0 ] && { echo "  -- created --"; printf '    + %s\n' "${C[@]}" | head -20; }
  [ ${#U[@]} -gt 0 ] && { echo "  -- updated --"; printf '    ~ %s\n' "${U[@]}" | head -20; }
  [ ${#M[@]} -gt 0 ] && printf '    ~ %s\n' "${M[@]}"
  [ ${#K[@]} -gt 0 ] && { echo "  -- 🔴 needs a human --"; printf '    ! %s\n' "${K[@]}" | head -30; rc=1; }
  [ ${#MC[@]} -gt 0 ] && { printf '    ! %s\n' "${MC[@]}"; rc=1; }
  [ ${#G[@]} -gt 0 ] && { echo "  -- dropped in the source (🔴 never deleted automatically; confirm yourself) --"; printf '    ? %s\n' "${G[@]}" | head -20; }
  if [ "$APPLY" = 1 ] || [ "$MODE" = adopt ]; then
    mkdir -p "$(dirname "$BL")"
    { echo "# synced from $SROLE $(basename "$SRC")  commit=$(cd "$SRC" && git rev-parse --short HEAD 2>/dev/null || echo -)  version=$(ver_read "$SRC" "$SROLE")  $(date +%F)"
      echo "# one line each: <content sha256> <relative path>; ROOT:<name> is a root-file mapping"
      LC_ALL=C sort -u "$TMP"; } > "$BL"
    echo "  ✅ baseline recorded: ${BL#$T/}"
    if [ "$APPLY" = 1 ]; then
      # 🔴 The target's FRAME-VERSION is stamped here: the version follows the source, **the fingerprint is
      #    the target's own** (FRAME-VERSION is seed and never copied; a copied value would make it lie).
      ver_write "$T" "$TROLE" "$(ver_read "$SRC" "$SROLE")" "$SRC" "$(fp_of "$SRC" "$SROLE")"
      echo "  ✅ target stamped $(ver_read "$SRC" "$SROLE") (fingerprint $(fp_of "$T" "$TROLE"), its own set)"
    fi
  else
    echo "  (dry-run: nothing written. To write: --apply. First baseline: --adopt)"
  fi
  rm -f "$TMP"; unset TB
done
exit $rc
