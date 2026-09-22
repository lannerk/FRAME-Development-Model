#!/usr/bin/env bash
# frame-sync -- what the command word "sync FRAME" actually does: bring this project's FRAME and the
# source repository into line, **without either side losing anything**.
#
# Usage (run from this project's root):
#   bash ops/frame/frame-sync.sh --status                   this repo's role, version and fingerprint
#   bash ops/frame/frame-sync.sh --sync                     reconcile both ways (**report only, writes nothing**)
#   bash ops/frame/frame-sync.sh --sync --apply             write both sides, once you have read the report
#   bash ops/frame/frame-sync.sh --adopt <repo>             take "what both sides look like now" as the baseline (first run; look before you adopt)
#   bash ops/frame/frame-sync.sh --diff <repo> <rel-path>   what exactly differs in one file
#   bash ops/frame/frame-sync.sh --dry-run|--apply <target…>  **distribute** from this repo to other projects (home/host only)
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
SELF="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$SELF/../.." && pwd)"
MODE="sync"; APPLY=0; ADOPT_MINE=0; DIST=0; STAMP_V=""; TARGETS=(); DIFF_T=""; DIFF_P=""; CLASSES="$SELF/classes.txt"
while [ $# -gt 0 ]; do
  case "$1" in
    --status|--fingerprint|--sync|--adopt) MODE="${1#--}" ;;
    --adopt-mine) MODE="adopt"; ADOPT_MINE=1 ;;
    --stamp) MODE="stamp"; STAMP_V="${2:-}"; shift ;;
    --dist) DIST=1 ;;   # the distribution side (the default is two-way reconciliation with the source)

    --dry-run) MODE="dist"; DIST=1 ;;
    --apply) APPLY=1; [ "$MODE" = "sync" ] || { MODE="dist"; DIST=1; } ;;
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
# 🔴 一个仓库可能有两份模板（中文／英文）。**一次只同步一份**，用 FRAME_TEMPLATE 指定另一份：
#   FRAME_TEMPLATE=ai/template-en bash ops/frame/frame-sync.sh --sync
# 不做成「一次跑两份」是因为指纹、基线、版本号都是按一份算的，混在一起就说不清谁跟谁一致。
base_of() { if [ "$2" = consumer ]; then echo "$1"; else
  local t; t="${FRAME_TEMPLATE:-$(conf_get "$1" template)}"; echo "$1/${t:-ai/template}"; fi; }

# -- Classes: <mode>[@role] <glob>; **the last match wins** ----------------
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

list_files() { local b; b="$(base_of "$1" "$2")"; (cd "$b" 2>/dev/null && find . -type f -printf '%P\n' | LC_ALL=C sort); }
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
ver_write() { local R="$1" RO="$2" V="$3" FROM="$4" f; f="$(ver_file "$R" "$RO")"
  mkdir -p "$(dirname "$f")"
  { echo "version: $V"; echo "date: $(date +%F)"; echo "fingerprint: $(fp_of "$R" "$RO")"
    echo "synced_with: $FROM"
    echo "# version is bumped by the Maintainer: structure/roles=major · rule semantics=minor · wording=patch"
    echo "# 🔴 the fingerprint is computed; never edit it by hand -- it is the only test of whether two sides are the same FRAME"
  } > "$f"; }

SROLE="$(role_of "$SRC")"
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
foreign_dirty() { # foreign_dirty <仓库> <基线文件（忽略，见下）> <该仓库里 FRAME 的前缀>
  # 🔴 判「是不是我们自己写的」要看**这个仓库对的全部基线**，不是当前这一份：
  # 一次同步可能分两份模板跑（中文、英文），先跑的那一份写进去的文件，在后跑的那一份眼里
  # 会变成「别人改的」——实测：英文那轮把中文那轮刚推的 21 份 ＋ 4 份根文件全报成别人的。
  local R="$1" _ignored="$2" PFX="$3" line st f rel cur out="" blf sfx pfx2
  [ -d "$R/.git" ] || return 1
  declare -A B=()
  for blf in "$SRC"/ops/frame/.baseline*; do
    [ -f "$blf" ] || continue
    sfx="${blf##*/.baseline}"                       # "" 或 "-template-en"
    # 🔴 没后缀那一份记的是**默认模板**（conf 里的 template=），不是「当前这一轮的模板」——
    # 按当前这一轮算前缀，会把中文那轮写的文件全对不上，于是又变成「别人的」（实测）。
    if [ -n "$sfx" ]; then pfx2="ai/${sfx#-}"
    elif [ "$(role_of "$R")" = consumer ]; then pfx2=""
    else pfx2="$(conf_get "$R" template)"; pfx2="${pfx2:-ai/template}"; fi
    while read -r a b; do
      case "$a" in ''|'#'*) continue;; esac
      case "$b" in ROOT:*) B["${b#ROOT:}"]="$a";; *) B["$pfx2/$b"]="$a";; esac
    done < "$blf"
  done
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    st="${line:0:2}"; f="${line:3}"
    case "$st" in '??') continue;; esac
    f="${f%\"}"; f="${f#\"}"
    rel="$f"; [ -n "$PFX" ] && rel="${f#$PFX/}"
    cur="$(h "$R/$f")"
    [ -n "${B[$rel]:-}" ] && [ "${B[$rel]}" = "$cur" ] && continue   # exactly what we wrote last time
    [ -n "${B[ROOT:$f]:-}" ] && [ "${B[ROOT:$f]}" = "$cur" ] && continue
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
# == Stamp the version (step 8 of the ten) ================================
# 🔴 **People bump the version, the machine computes the fingerprint**: this command writes the same version
# into ai/FRAME-VERSION on both sides, each with its freshly computed fingerprint (they should match).
# The version file itself is outside the fingerprint, so stamping does not change it.
if [ "$MODE" = stamp ]; then
  [ -n "$STAMP_V" ] || { echo "usage: --stamp <version> (structure/roles=major · rule semantics=minor · wording=patch)"; exit 2; }
  HOME_REPO="${TARGETS[0]:-$(conf_get "$SRC" home)}"
  if [ -n "$HOME_REPO" ] && [ ! -d "$HOME_REPO" ]; then
    alt="$HOME/mnt/$(basename "$(printf '%s' "$HOME_REPO" | tr '\\' '/')")"; [ -d "$alt" ] && HOME_REPO="$alt"; fi
  [ -d "$HOME_REPO" ] || { echo "🔴 cannot find the source FRAME repo"; exit 2; }
  HROLE="$(role_of "$HOME_REPO")"
  ver_write "$SRC" "$SROLE" "$STAMP_V" "$(conf_get "$SRC" home)"
  ver_write "$HOME_REPO" "$HROLE" "$STAMP_V" "$SRC"
  echo "✅ both sides stamped $STAMP_V: this project $(fp_of "$SRC" "$SROLE")   source $(fp_of "$HOME_REPO" "$HROLE")"
  echo "   (template: ${FRAME_TEMPLATE:-$(conf_get "$SRC" template)}; the other template needs its own run)"
  exit 0
fi

# 🔴 `--adopt` defaults to the **two-way reconciliation** side; to lay a baseline in another project you must say
# `--dist --adopt <target>` explicitly. (Without this switch, `--adopt <target>` was read as "treat this target as the
# source", and the baseline went into this repo while the target got nothing.)
if [ "$DIST" != 1 ] && { [ "$MODE" = sync ] || [ "$MODE" = adopt ]; }; then
  HOME_REPO="${TARGETS[0]:-$(conf_get "$SRC" home)}"
  # 【One conf, two kinds of machine】`home=` holds the real path on the owner's machine (a Windows D:\… path).
  # The same repository is mounted elsewhere in a cloud session. **Do not edit the conf for that** (it states the truth);
  # instead, when the configured path does not exist, look for a mount point of the same name and say which one is used.
  if [ -n "$HOME_REPO" ] && [ ! -d "$HOME_REPO" ]; then
    alt="$HOME/mnt/$(basename "$(printf '%s' "$HOME_REPO" | tr '\\' '/')")"
    [ -d "$alt" ] && { echo "ℹ️  home= from the conf does not exist on this machine; using the mount point of the same name: $alt"; HOME_REPO="$alt"; }
  fi
  [ -n "$HOME_REPO" ] && [ -d "$HOME_REPO" ] || { echo "🔴 cannot find the source FRAME repo (home= in ai/frame-repo.conf, or pass one on the command line)"; exit 2; }
  HROLE="$(role_of "$HOME_REPO")"; HBASE="$(base_of "$HOME_REPO" "$HROLE")"
  SFP="$(fp_of "$SRC" "$SROLE")"; HFP="$(fp_of "$HOME_REPO" "$HROLE")"
  echo "this project: $SRC   role $SROLE   version $(ver_read "$SRC" "$SROLE")   fingerprint $SFP"
  echo "source FRAME: $HOME_REPO   role $HROLE   version $(ver_read "$HOME_REPO" "$HROLE")   fingerprint $HFP"
  # Even with equal fingerprints, check the root files (they are outside the fingerprint but part of this FRAME)
  if [ "$SFP" = "$HFP" ] && [ "$MODE" = sync ]; then
    roots_project "$HOME_REPO" "$APPLY"
    echo "✅ identical fingerprints -- already the same FRAME; nothing to sync (not one file touched)."; exit 0; fi

# 🔴 **One baseline per template**: the two templates use identical relative paths (`ai/rules/laws.md` exists in
# both), so sharing one baseline reads "the other template's content" as "someone changed this one" -- 22 false
# conflicts in practice.
  BLSFX=""; [ -n "${FRAME_TEMPLATE:-}" ] && BLSFX="-$(basename "$FRAME_TEMPLATE")"
  BL="$SRC/ops/frame/.baseline$BLSFX"
  declare -A BASE=()
  [ -f "$BL" ] && while read -r a b; do case "$a" in ''|'#'*) continue;; *) BASE["$b"]="$a";; esac; done < "$BL"

  PULL=(); PUSH=(); CONF=(); GONE=(); SAME=0; SEEDN=0; SKIPN=0; UNK=0
  TMPBL="$(mktemp)"
  ALL="$( { list_files "$SRC" "$SROLE"; list_files "$HOME_REPO" "$HROLE"; } | LC_ALL=C sort -u )"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    cs="$(class_of "$rel" "$SROLE")"; ch="$(class_of "$rel" "$HROLE")"
    if [ "$cs" = skip ] || [ "$ch" = skip ]; then SKIPN=$((SKIPN+1)); continue; fi
    sh="$(h "$SBASE/$rel")"; hh="$(h "$HBASE/$rel")"; bh="${BASE[$rel]:--}"
    if [ "$sh" = "$hh" ]; then SAME=$((SAME+1)); echo "$sh $rel" >> "$TMPBL"; continue; fi
    # 🔴 seed files never take part in two-way overwriting: a project fills them in, and pushing them back would carry project content into FRAME
    if [ "$cs" = seed ] || [ "$ch" = seed ]; then
      if   [ "$sh" = "-" ]; then PULL+=("$rel  (skeleton, created)")
      elif [ "$hh" = "-" ]; then PUSH+=("$rel  (skeleton, created)")
      else SEEDN=$((SEEDN+1)); [ "$bh" != "-" ] && echo "$bh $rel" >> "$TMPBL"; fi
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
  printf '  🔴 needs a human %-4s (of which %s are "no baseline")\n' ${#CONF[@]} $UNK
  [ ${#PULL[@]} -gt 0 ] && { echo "  -- <- pull in --"; printf '    %s\n' "${PULL[@]}" | head -30; }
  [ ${#PUSH[@]} -gt 0 ] && { echo "  -- -> push out --"; printf '    %s\n' "${PUSH[@]}" | head -30; }
  [ ${#GONE[@]} -gt 0 ] && { echo "  -- one side deleted it (🔴 never deleted automatically; confirm yourself) --"; printf '    ? %s\n' "${GONE[@]}" | head -20; }
  [ ${#CONF[@]} -gt 0 ] && { echo "  -- 🔴 needs a human (reported, nothing written) --"; printf '    ! %s\n' "${CONF[@]}" | head -30
    echo "    see the difference: bash ops/frame/frame-sync.sh --diff \"$HOME_REPO\" <path from above>"; }
  if [ ${#PUSH[@]} -eq 0 ] && [ ${#CONF[@]} -eq 0 ] && [ ${#PULL[@]} -gt 0 ]; then
    echo "  ℹ️  this project has not changed FRAME -- so this run is simply **a one-way pull from the source** (version number included)."; fi

  if [ "$MODE" = adopt ]; then
    mkdir -p "$(dirname "$BL")"
    { echo "# adopt: taking what both sides look like now as the baseline  $(date +%F)  source=$HOME_REPO"
      echo "# one line each: <content sha256> <relative path>. 🔴 adopt accepts the current state as correct -- look before you adopt."
      LC_ALL=C sort -u "$TMPBL"; } > "$BL"
    echo "  ✅ baseline recorded: ${BL#$SRC/} ($(grep -vc '^#' "$BL") entries)"
    rm -f "$TMPBL"; exit 0; fi

  if [ "$APPLY" != 1 ]; then
    echo "  (this is a report; nothing was written. To write: --sync --apply. First baseline: --adopt)"
    rm -f "$TMPBL"; [ ${#CONF[@]} -gt 0 ] && exit 1; exit 0; fi

  # -- iron rules 1 and 2: both sides must be clean --
  if git_dirty "$SRC" "${SBASE#$SRC/}"; then
    echo "🔴 this project has uncommitted FRAME changes -- refusing to write. **Only committed FRAME counts**; commit first."; rm -f "$TMPBL"; exit 1; fi
  # 🔴 Judge the source repo's dirt against **this project's baseline**: it holds "the content both sides last
  #    agreed on", so anything in the source matching it is exactly what the last sync wrote. The source's own
  #    distribution baseline would judge it wrong (that one records what the target looked like *before* a push).
  FOREIGN="$(foreign_dirty "$HOME_REPO" "$BL" "${HBASE#$HOME_REPO/}" || true)"
  if [ -n "$FOREIGN" ]; then
    echo "🔴 the source repo has **someone else's** uncommitted changes -- refusing to write:$FOREIGN"; rm -f "$TMPBL"; exit 1; fi
  # -- iron rule: with conflicts, nothing is written --
  if [ ${#CONF[@]} -gt 0 ]; then
    echo "🔴 ${#CONF[@]} entries need a human, so **nothing is written**. Say \"sync FRAME\" again once they are handled."; rm -f "$TMPBL"; exit 1; fi

  for e in "${PULL[@]}"; do rel="${e%%  (*}"; rel="${rel% }"
    mkdir -p "$(dirname "$SBASE/$rel")"; cpn "$HBASE/$rel" "$SBASE/$rel"; done
  for e in "${PUSH[@]}"; do rel="${e%%  (*}"; rel="${rel% }"
    mkdir -p "$(dirname "$HBASE/$rel")"; cpn "$SBASE/$rel" "$HBASE/$rel"; done
  echo "  ✅ written: pulled in ${#PULL[@]} · pushed out ${#PUSH[@]} (🔴 never deletes: a file dropped in the source is only reported above)"
  roots_project "$HOME_REPO" 1
  NFP="$(fp_of "$SRC" "$SROLE")"; NHFP="$(fp_of "$HOME_REPO" "$HROLE")"
  echo "  fingerprints recomputed: this project $NFP   source $NHFP"
  [ "$NFP" = "$NHFP" ] || echo "  ⚠️ the fingerprints still differ -- usually seed files kept as-is (normal), or a difference nobody handled."
  echo "  next (for a human): bump the version -> write ai/FRAME-VERSION on both sides -> one maintenance-log line each -> commit the source repo and push it to GitHub."
  # 铁律 5：重记基线
  { echo "# re-recorded after apply  $(date +%F)  source=$HOME_REPO"
    # 🔴 Root files go into the baseline too: without them the next run has nothing to judge "who changed these"
    # against, and since this run just projected them, it would read them as someone else's (measured).
    while IFS= read -r mline; do
      [ -n "$mline" ] || continue
      rootf="${mline%%:*}"
      printf '%s ROOT:%s\n' "$(h "$HOME_REPO/$rootf")" "$rootf"
    done < <(conf_all "$HOME_REPO" map)
    while IFS= read -r rel; do [ -n "$rel" ] || continue
      cs="$(class_of "$rel" "$SROLE")"; [ "$cs" = skip ] && continue
      printf '%s %s\n' "$(h "$SBASE/$rel")" "$rel"
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
  if [ "$APPLY" = 1 ] && git_dirty "$T"; then
    echo "🔴 the target working tree has uncommitted changes -- refusing to write."; rc=1; continue; fi
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
    elif [ "$th" = "$bh" ]; then nU=$((nU+1)); U+=("$rel")
      [ "$APPLY" = 1 ] && cpn "$s" "$t"; echo "$sh $rel" >> "$TMP"
    else nConf=$((nConf+1)); K+=("$rel  (target changed it)"); echo "$th $rel" >> "$TMP"; fi
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
    { echo "# synced from $SROLE $SRC  commit=$(cd "$SRC" && git rev-parse --short HEAD 2>/dev/null || echo -)  version=$(ver_read "$SRC" "$SROLE")  $(date +%F)"
      echo "# one line each: <content sha256> <relative path>; ROOT:<name> is a root-file mapping"
      LC_ALL=C sort -u "$TMP"; } > "$BL"
    echo "  ✅ baseline recorded: ${BL#$T/}"
  else
    echo "  (dry-run: nothing written. To write: --apply. First baseline: --adopt)"
  fi
  rm -f "$TMP"; unset TB
done
exit $rc
