#!/usr/bin/env bash
# frame-sync —— 口令「同步 FRAME」背后的那套动作：把本项目的 FRAME 与源仓库对齐，**且不让任何一边丢东西**。
#
# 用法（在本项目根目录跑）：
#   bash ops/frame/frame-sync.sh --status                  本仓库的角色 · 版本 · 指纹
#   bash ops/frame/frame-sync.sh --sync                    双向对账（**只报不写**）
#   bash ops/frame/frame-sync.sh --sync --apply            确认之后才写两边
#   bash ops/frame/frame-sync.sh --adopt <仓库>            把「现在两边这样」收为基线（首次用，先看过再认）
#   bash ops/frame/frame-sync.sh --diff <仓库> <相对路径>   某一份到底差在哪
#   bash ops/frame/frame-sync.sh --dry-run|--apply <目标…>  从本仓库**分发**给别的项目（home/host 才有意义）
# 退出码 0 = 已对齐或报告完；1 = 有要人处理的；2 = 结构/参数不对。
#
# 🔴 五条铁律（都在代码里，不是口号）：
#   1 源工作区脏 → 拒绝 --apply（**只认已提交的 FRAME**：半成品同步出去，下游拿到的是谁都没验过的规矩）
#   2 目标工作区脏 → 拒绝写（冲突会和本地改动搅在一起）
#   3 默认 dry-run，--apply 必须显式给
#   4 **从不删除**：源删了只报告
#   5 apply / adopt 之后重记基线
#
# 【判的是要保的那件事】
#   · **指纹给机器判，版本号给人看**：指纹＝所有 follow 类内容的聚合哈希，自动算；version 由维护席 bump。
#     只靠版本号判，忘了 bump 就会把旧的当新的（`check-template-sync` v1 用 mtime 也栽过同一类跟头）。
#   · **按内容比，不按字节比**：先去掉 CR。实测 README-zh_CN.md 是 CRLF，按字节比 292 行全报「改了」。
#   · **默认 seed，只有显式列出的才 follow**：漏分类一个新文件，结果是「被创建」而不是「盖掉目标已有的」。
#     反过来设计，漏一条就静默丢东西，**而且没有症状**。
set -u
SELF="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$SELF/../.." && pwd)"
MODE="sync"; APPLY=0; ADOPT_MINE=0; DIST=0; STAMP_V=""; TARGETS=(); DIFF_T=""; DIFF_P=""; CLASSES="$SELF/classes.txt"
while [ $# -gt 0 ]; do
  case "$1" in
    --status|--fingerprint|--sync|--adopt) MODE="${1#--}" ;;
    --adopt-mine) MODE="adopt"; ADOPT_MINE=1 ;;
    --stamp) MODE="stamp"; STAMP_V="${2:-}"; shift ;;
    --dist) DIST=1 ;;   # 分发给别的项目这一侧（默认是与源仓库双向对账）

    --dry-run) MODE="dist"; DIST=1 ;;
    --apply) APPLY=1; [ "$MODE" = "sync" ] || { MODE="dist"; DIST=1; } ;;
    --diff) MODE="diff"; DIFF_T="${2:-}"; DIFF_P="${3:-}"; shift 2 ;;
    --classes) CLASSES="${2:-}"; shift ;;
    -*) echo "不认识的参数：$1"; exit 2 ;;
    *) TARGETS+=("$1") ;;
  esac; shift
done
[ -f "$CLASSES" ] || { echo "找不到分类表：$CLASSES"; exit 2; }

# ── 仓库画像（ai/frame-repo.conf）────────────────────────────────────
# 🔴 脚本里不写死任何仓库名：加一个项目 = 加一份 conf，不改脚本。
conf_get() { [ -f "$1/ai/frame-repo.conf" ] || { echo ""; return; }
  grep -E "^$2=" "$1/ai/frame-repo.conf" | head -1 | cut -d= -f2-; }
conf_all() { [ -f "$1/ai/frame-repo.conf" ] || return 0
  grep -E "^$2=" "$1/ai/frame-repo.conf" | cut -d= -f2-; }
role_of() { local r; r="$(conf_get "$1" role)"; [ -n "$r" ] && { echo "$r"; return; }
  if [ -d "$1/ai/template" ] && [ ! -d "$1/src" ]; then echo home
  elif [ -d "$1/ai/template" ]; then echo host; else echo consumer; fi; }
# FRAME 在这个仓库里落在哪：带模板的落模板目录，consumer 落项目根
# 🔴 一个仓库可能有两份模板（中文／英文）。**一次只同步一份**，用 FRAME_TEMPLATE 指定另一份：
#   FRAME_TEMPLATE=ai/template-en bash ops/frame/frame-sync.sh --sync
# 不做成「一次跑两份」是因为指纹、基线、版本号都是按一份算的，混在一起就说不清谁跟谁一致。
base_of() { if [ "$2" = consumer ]; then echo "$1"; else
  local t; t="${FRAME_TEMPLATE:-$(conf_get "$1" template)}"; echo "$1/${t:-ai/template}"; fi; }

# ── 分类：<模式>[@角色] <glob>，**最后匹配的那条胜出** ────────────────
class_of() { local p="$1" role="$2" m=seed mode pat mrole
  while read -r mode pat; do
    case "$mode" in ''|'#'*) continue;; esac
    [ -n "${pat:-}" ] || continue
    mrole=""; case "$mode" in *@*) mrole="${mode#*@}"; mode="${mode%@*}";; esac
    [ -n "$mrole" ] && [ "$mrole" != "$role" ] && continue
    if [ "$pat" = '**' ]; then m="$mode"; else case "$p" in $pat) m="$mode";; esac; fi
  done < "$CLASSES"
  echo "$m"; }

# 🔴 内容哈希：去掉 CR 再算（换行风格不算「改了」）
h() { [ -f "$1" ] && tr -d '\r' < "$1" | sha256sum | cut -d' ' -f1 || echo "-"; }
hs() { tr -d '\r' < "$1" | sha256sum | cut -d' ' -f1; }   # 给临时文件用
# 写入时保留目标原有的换行风格，免得一次同步把整份文件变成一个大 diff
cpn() { local s="$1" d="$2"
  if [ -f "$d" ] && head -c 4000 "$d" | grep -q $'\r'; then
    awk '{ sub(/\r$/,""); printf "%s\r\n", $0 }' "$s" > "$d"
  else cp "$s" "$d"; fi; }

list_files() { local b; b="$(base_of "$1" "$2")"; (cd "$b" 2>/dev/null && find . -type f -printf '%P\n' | LC_ALL=C sort); }
fp_of() { local R="$1" RO="$2" b rel
  b="$(base_of "$R" "$RO")"
  { while IFS= read -r rel; do
      [ "$(class_of "$rel" "$RO")" = follow ] || continue
      # 🔴 版本文件自己不进指纹：它里面写的就是指纹，算进去会自己咬自己
      # （写一次版本文件 → 指纹变 → 写进去的那个指纹当场过期）。它照样 follow、照样同步。
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
    echo "# version 由维护席 bump：结构/角色变=major · 规矩语义变=minor · 措辞=patch"
    echo "# 🔴 fingerprint 自动算，别手改——它是「两边是不是同一套 FRAME」的唯一判据"
  } > "$f"; }

SROLE="$(role_of "$SRC")"
SBASE="$(base_of "$SRC" "$SROLE")"
[ -d "$SBASE" ] || { echo "🔴 本仓库找不到 FRAME 落点：$SBASE"; exit 2; }

case "$MODE" in
  fingerprint) echo "$(fp_of "$SRC" "$SROLE")  版本 $(ver_read "$SRC" "$SROLE")"; exit 0;;
  status)
    echo "仓库    : $SRC"
    echo "角色    : $SROLE"
    echo "FRAME 在: ${SBASE#$SRC/}（$(list_files "$SRC" "$SROLE" | grep -c . ) 个文件）"
    echo "版本    : $(ver_read "$SRC" "$SROLE")   指纹 $(fp_of "$SRC" "$SROLE")"
    echo "源仓库  : $(conf_get "$SRC" home)"
    exit 0;;
  diff)
    [ -n "$DIFF_T" ] && [ -n "$DIFF_P" ] || { echo "用法：--diff <仓库> <相对路径>"; exit 2; }
    diff -u "$(base_of "$DIFF_T" "$(role_of "$DIFF_T")")/$DIFF_P" "$SBASE/$DIFF_P" || true
    exit 0;;
esac

# 🔴 「脏」判的是**已跟踪文件被改过**，不是「有没有没入库的文件」：
# 未跟踪的新文件（比如这套机制自己刚建的 conf 与基线）不会被我们的写入冲掉——
# 要保的那件事是「别和别人未提交的改动搅在一起」，不是「工作区必须一尘不染」。
# 把未跟踪也算脏的后果很具体：机制自己建的文件会让它自己永远跑不起来。
git_dirty() { [ -d "$1/.git" ] || return 1
  [ -n "$(cd "$1" && git status --porcelain -- "${2:-.}" 2>/dev/null | grep -v '^??')" ]; }
# 🔴 要保的那件事是「**别和别人的未提交改动搅在一起**」，不是「工作区必须干净」。
# 判据：已跟踪、被改过的那几份里，**内容正好等于基线里记的那一份** = 上一次同步自己写的，不算别人的。
# 【为什么要这条】首次同步是「先写模板、再投影根文件」两步，第一步写完目标就脏了，
# 整仓判定会让同一次同步的后半步被自己挡在门外（实测撞上过两次）。
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
    cur="$(h "$R/$f")"
    [ -n "${B[$f]:-}" ] && [ "${B[$f]}" = "$cur" ] && continue   # 就是我们（某一轮）写进去的那一份
    out="$out $f"
  done < <(cd "$R" && git status --porcelain 2>/dev/null)
  [ -n "$out" ] && { echo "$out"; return 0; }
  return 1
}
git_untracked() { [ -d "$1/.git" ] || return 1
  [ -n "$(cd "$1" && git status --porcelain -- "${2:-.}" 2>/dev/null | grep '^??')" ]; }

# ── 根文件投影（map= / patch=）：源仓库根上那几份 = 模板 ＋ 声明式补丁 ──
# 🔴 **它是同一次同步的一部分**，所以放函数里、两处都调：指纹一样时也要看它们在不在位。
# 🔴 这里**不做整仓「脏」判定**，只逐份看那一份根文件自己有没有被人手改过——
#    整仓判定会让同一次同步的前半步（刚写完模板）把后半步挡在门外（实测撞上过）。
roots_project() { # roots_project <源FRAME仓库> <要不要写>
  local HR="$1" DOIT="$2" mline rootf tplrel srcf proj pl expr before n=0 fail=0 dirtyf
  # ── 源仓库的根文件（map= / patch=）是**同一次同步的一部分**，同轮投影 ──
  # 【为什么不放到「分发」那一侧去做】放那边要再跑一条命令，而那时源仓库已经被这一步写脏了，
  # 铁律 2 会把它自己挡在门外（实测撞上过）。**一次同步就该让两边都到位。**
  
  while IFS= read -r mline; do
    [ -n "$mline" ] || continue
    rootf="${mline%%:*}"; tplrel="${mline#*:}"; srcf="$SBASE/${tplrel#ai/template/}"
    [ -f "$SRC/$tplrel" ] && srcf="$SRC/$tplrel"
    [ -f "$srcf" ] || { echo "  🔴 map 的源不存在：$tplrel"; fail=$((fail+1)); continue; }
    proj="$(mktemp)"; cp "$srcf" "$proj"
    while IFS= read -r pl; do
      [ -n "$pl" ] || continue
      [ "${pl%%:*}" = "$rootf" ] || continue
      expr="${pl#*:}"; before="$(hs "$proj")"
      sed -i "$expr" "$proj" 2>/dev/null || true
      [ "$(hs "$proj")" = "$before" ] && { fail=$((fail+1))
        echo "  🔴 补丁没套上（源改了措辞？要人更新这条补丁）：$rootf  ${expr:0:44}"; }
    done < <(conf_all "$HR" patch)
    if [ "$(hs "$proj")" != "$(h "$HR/$rootf")" ]; then
      if [ -d "$HR/.git" ] && [ -n "$(cd "$HR" && git status --porcelain -- "$rootf" 2>/dev/null | grep -v '^??')" ]; then
        echo "  🔴 $rootf 被人手改过（未提交）——只报不改：手工改完下次同步一定报冲突"; fail=$((fail+1)); rm -f "$proj"; continue
      fi
      [ "$DOIT" = 1 ] && cpn "$proj" "$HR/$rootf"; n=$((n+1)); echo "    ~ 根文件 $rootf  ← $tplrel"
    fi
    rm -f "$proj"
  done < <(conf_all "$HR" map)
  [ $((n+fail)) -gt 0 ] && printf '  根文件：更新 %s  补丁失效 %s\n' $n $fail
  return 0
}


# ══ 双向同步（口令「同步 FRAME」）═══════════════════════════════════
# ══ 盖版本号（口令那十步的第 8 步）══════════════════════════════════
# 🔴 **版本号人 bump，指纹机器算**：这一条命令把两边的 ai/FRAME-VERSION 写成同一个版本，
# 指纹各自现算（两边应当相同）。版本文件自己不进指纹，所以盖完指纹不变。
if [ "$MODE" = stamp ]; then
  [ -n "$STAMP_V" ] || { echo "用法：--stamp <版本号>（结构/角色变=major · 规矩语义变=minor · 措辞=patch）"; exit 2; }
  HOME_REPO="${TARGETS[0]:-$(conf_get "$SRC" home)}"
  if [ -n "$HOME_REPO" ] && [ ! -d "$HOME_REPO" ]; then
    alt="$HOME/mnt/$(basename "$(printf '%s' "$HOME_REPO" | tr '\\' '/')")"; [ -d "$alt" ] && HOME_REPO="$alt"; fi
  [ -d "$HOME_REPO" ] || { echo "🔴 找不到源 FRAME 仓库"; exit 2; }
  HROLE="$(role_of "$HOME_REPO")"
  ver_write "$SRC" "$SROLE" "$STAMP_V" "$(conf_get "$SRC" home)"
  ver_write "$HOME_REPO" "$HROLE" "$STAMP_V" "$SRC"
  echo "✅ 两边都盖上 $STAMP_V：本项目指纹 $(fp_of "$SRC" "$SROLE")   源 $(fp_of "$HOME_REPO" "$HROLE")"
  echo "   （模板：${FRAME_TEMPLATE:-$(conf_get "$SRC" template)}；另一份模板要另跑一次）"
  exit 0
fi

# 🔴 `--adopt` 默认走的是**与源仓库双向对账**那一侧；要给别的项目立基线，得显式 `--dist --adopt <目标>`。
# （第一版没有这个开关，`--adopt <目标>` 被当成「拿这个目标当源」，基线写进了本仓库，**目标那边一条都没记**。）
if [ "$DIST" != 1 ] && { [ "$MODE" = sync ] || [ "$MODE" = adopt ]; }; then
  HOME_REPO="${TARGETS[0]:-$(conf_get "$SRC" home)}"
  # 【同一份 conf 要在两种机器上都能用】`home=` 写的是需求方那台机器上的真实路径（Windows 的 D:\…）。
  # 同一个仓库在云端会话里是挂载进来的，路径不一样。**不为此改 conf**（那份 conf 是给人看的真相），
  # 改成：配置的路径不存在时，按**同名挂载点**再找一次，找到了就说明白用的是哪一个。
  if [ -n "$HOME_REPO" ] && [ ! -d "$HOME_REPO" ]; then
    alt="$HOME/mnt/$(basename "$(printf '%s' "$HOME_REPO" | tr '\\' '/')")"
    [ -d "$alt" ] && { echo "ℹ️  conf 里的 home= 在这台机器上不存在，改用同名挂载点：$alt"; HOME_REPO="$alt"; }
  fi
  [ -n "$HOME_REPO" ] && [ -d "$HOME_REPO" ] || { echo "🔴 找不到源 FRAME 仓库（ai/frame-repo.conf 的 home=，或命令行给一个）"; exit 2; }
  HROLE="$(role_of "$HOME_REPO")"; HBASE="$(base_of "$HOME_REPO" "$HROLE")"
  SFP="$(fp_of "$SRC" "$SROLE")"; HFP="$(fp_of "$HOME_REPO" "$HROLE")"
  echo "本项目 : $SRC   角色 $SROLE   版本 $(ver_read "$SRC" "$SROLE")   指纹 $SFP"
  echo "源FRAME: $HOME_REPO   角色 $HROLE   版本 $(ver_read "$HOME_REPO" "$HROLE")   指纹 $HFP"
  # 指纹一样也要看一眼根文件（它们不进指纹，但属于这一套 FRAME）
  if [ "$SFP" = "$HFP" ] && [ "$MODE" = sync ]; then
    roots_project "$HOME_REPO" "$APPLY"
    echo "✅ 两边指纹相同 —— 已经是同一套 FRAME，无需同步（一个文件都没动）。"; exit 0; fi

# 🔴 **一份模板一份基线**：两份模板的相对路径是一样的（`ai/rules/laws.md` 在中英两边都叫这个名），
# 共用一份基线会把「另一份模板的内容」当成「这一份被人改过」，**22 份全变成假冲突**（实测）。
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
    # 🔴 seed 类永远不参与双向覆盖：项目里填过内容，push 回源会把项目内容带进 FRAME
    if [ "$cs" = seed ] || [ "$ch" = seed ]; then
      if   [ "$sh" = "-" ]; then PULL+=("$rel  (骨架·新建)")
      elif [ "$hh" = "-" ]; then PUSH+=("$rel  (骨架·新建)")
      else SEEDN=$((SEEDN+1)); [ "$bh" != "-" ] && echo "$bh $rel" >> "$TMPBL"; fi
      continue; fi
    # 🔴 **adopt 必须说清「以哪一边为准」**：基线的意思是「上次两边一致的那份内容」。
    # 记成源那边 ⇒ 本项目与它的差异算**我改的**，下一轮**推出去**（首次同步的常见情形）；
    # 记成本项目这边（--adopt-mine）⇒ 差异算**对方改的**，下一轮**拉回来**。
    # 第一版无条件记本项目的哈希，于是「我比源新」反而被判成「源改了」，**下一轮会把旧版拉回来盖掉新的**——
    # 差一点就把这一轮写的东西全冲了。判的是方向，不是「记一笔」。
    if [ "$MODE" = adopt ]; then
      if [ "$ADOPT_MINE" = 1 ]; then [ "$sh" != "-" ] && echo "$sh $rel" >> "$TMPBL"
      else [ "$hh" != "-" ] && echo "$hh $rel" >> "$TMPBL"; fi
      SAME=$((SAME+1)); continue; fi
    # 🔴 「没有了」分两种：**从来没有过**（新增）和**基线里有、现在没了**（被删）。
    # 判错这一格的后果不对称：把「被删」当成「新增」，会把对方刚删掉的文件又推回去，
    # 而且**每同步一次就复活一次**，人永远删不掉。按铁律 4：删除只报告，绝不自动做。
    if   [ "$sh" = "-" ] && [ "$bh" != "-" ]; then GONE+=("$rel  (本项目删了它，源那边还在——只报告，不自动删)")
    elif [ "$hh" = "-" ] && [ "$bh" != "-" ]; then GONE+=("$rel  (源删了它，本项目还在——只报告，不自动删)")
    elif [ "$sh" = "-" ]; then PULL+=("$rel  (源新增)")
    elif [ "$hh" = "-" ]; then PUSH+=("$rel  (本项目新增)")
    elif [ "$bh" = "-" ]; then UNK=$((UNK+1)); CONF+=("$rel  (没有基线，分不清谁改的)"); echo "$sh $rel" >> "$TMPBL"
    elif [ "$sh" = "$bh" ]; then PULL+=("$rel")
    elif [ "$hh" = "$bh" ]; then PUSH+=("$rel")
    else CONF+=("$rel  🔴 两边都改了"); echo "$sh $rel" >> "$TMPBL"; fi
  done <<< "$ALL"

  echo "──────────────────────────────────────────"
  printf '  ← 拉回本项目 %-4s  → 推到源 %-4s  一致 %-4s  seed各留各的 %-4s  跳过 %-4s\n' ${#PULL[@]} ${#PUSH[@]} $SAME $SEEDN $SKIPN
  printf '  🔴 要人处理 %-4s（其中「没有基线」%s 条）\n' ${#CONF[@]} $UNK
  [ ${#PULL[@]} -gt 0 ] && { echo "  ── ← 拉回 ──"; printf '    %s\n' "${PULL[@]}" | head -30; }
  [ ${#PUSH[@]} -gt 0 ] && { echo "  ── → 推出 ──"; printf '    %s\n' "${PUSH[@]}" | head -30; }
  [ ${#GONE[@]} -gt 0 ] && { echo "  ── 一边删了（🔴 从不自动删，自己确认）──"; printf '    ? %s\n' "${GONE[@]}" | head -20; }
  [ ${#CONF[@]} -gt 0 ] && { echo "  ── 🔴 要人处理（只报不改）──"; printf '    ! %s\n' "${CONF[@]}" | head -30
    echo "    看差异：bash ops/frame/frame-sync.sh --diff \"$HOME_REPO\" <上面的路径>"; }
  if [ ${#PUSH[@]} -eq 0 ] && [ ${#CONF[@]} -eq 0 ] && [ ${#PULL[@]} -gt 0 ]; then
    echo "  ℹ️  本项目没改过 FRAME —— 这一次就是**单向从源拉回来**（含版本号）。"; fi

  if [ "$MODE" = adopt ]; then
    mkdir -p "$(dirname "$BL")"
    { echo "# adopt：把「现在两边这样」收为基线  $(date +%F)  源=$HOME_REPO"
      echo "# 一行：<内容sha256> <相对路径>。🔴 adopt 等于承认现状是对的——**先看过再认**。"
      LC_ALL=C sort -u "$TMPBL"; } > "$BL"
    echo "  ✅ 基线已记：${BL#$SRC/}（$(grep -vc '^#' "$BL") 条）"
    rm -f "$TMPBL"; exit 0; fi

  if [ "$APPLY" != 1 ]; then
    echo "  （这是报告，什么都没写。真要写：--sync --apply；首次建基线：--adopt）"
    rm -f "$TMPBL"; [ ${#CONF[@]} -gt 0 ] && exit 1; exit 0; fi

  # ── 铁律 1/2：两边都必须干净 ──
  if git_dirty "$SRC" "${SBASE#$SRC/}"; then
    echo "🔴 本项目的 FRAME 有未提交改动——拒绝写。**只认已提交的 FRAME**，先提交再同步。"; rm -f "$TMPBL"; exit 1; fi
  # 🔴 拿**本项目的基线**去判源仓库的脏：基线记的就是「上次两边一致的那份内容」，
  #    源仓库里内容等于它的那几份，正是上一轮同步自己写进去的。用源仓库自己那份分发基线会判错
  #    （那一份记的是「分发之前目标长什么样」）。
  FOREIGN="$(foreign_dirty "$HOME_REPO" "$BL" "${HBASE#$HOME_REPO/}" || true)"
  if [ -n "$FOREIGN" ]; then
    echo "🔴 源仓库里有**别人**的未提交改动，拒绝写（冲突会和它们搅在一起）：$FOREIGN"; rm -f "$TMPBL"; exit 1; fi
  # ── 铁律：有冲突一律不写 ──
  if [ ${#CONF[@]} -gt 0 ]; then
    echo "🔴 有 ${#CONF[@]} 条要人处理，**一条都不写**。人处理完再喊一次「同步 FRAME」。"; rm -f "$TMPBL"; exit 1; fi

  for e in "${PULL[@]}"; do rel="${e%%  (*}"; rel="${rel% }"
    mkdir -p "$(dirname "$SBASE/$rel")"; cpn "$HBASE/$rel" "$SBASE/$rel"; done
  for e in "${PUSH[@]}"; do rel="${e%%  (*}"; rel="${rel% }"
    mkdir -p "$(dirname "$HBASE/$rel")"; cpn "$SBASE/$rel" "$HBASE/$rel"; done
  echo "  ✅ 写完：拉回 ${#PULL[@]} · 推出 ${#PUSH[@]}（🔴 从不删除：源删了只在上面报告）"
  roots_project "$HOME_REPO" 1
  NFP="$(fp_of "$SRC" "$SROLE")"; NHFP="$(fp_of "$HOME_REPO" "$HROLE")"
  echo "  重算指纹：本项目 $NFP   源 $NHFP"
  [ "$NFP" = "$NHFP" ] || echo "  ⚠️ 两边指纹仍不同——多半是 seed 类各留各的（正常），或还有没处理的差异。"
  echo "  下一步（人做）：bump 版本 → 两边写 ai/FRAME-VERSION → 各记一行维护记录 → 源仓库提交并推 GitHub。"
  # 铁律 5：重记基线
  { echo "# apply 之后重记  $(date +%F)  源=$HOME_REPO"
    # 🔴 根文件也要记进基线：不记的话，下一轮判「这几份是谁改的」就没有依据，
    # 而它们刚被这一轮投影过——会被自己判成「别人改的」（实测）。
    while IFS= read -r mline; do
      [ -n "$mline" ] || continue
      rootf="${mline%%:*}"
      printf '%s ROOT:%s\n' "$(h "$HOME_REPO/$rootf")" "$rootf"
    done < <(conf_all "$HOME_REPO" map)
    while IFS= read -r rel; do [ -n "$rel" ] || continue
      cs="$(class_of "$rel" "$SROLE")"; [ "$cs" = skip ] && continue
      printf '%s %s\n' "$(h "$SBASE/$rel")" "$rel"
    done <<< "$ALL"; } > "$BL"
  echo "  ✅ 基线已重记：${BL#$SRC/}"
  rm -f "$TMPBL"; exit 0
fi

# ══ 分发给别的项目（home/host 用）═══════════════════════════════════
if [ ${#TARGETS[@]} -eq 0 ] && [ -f "$SRC/ops/frame/targets.txt" ]; then
  while IFS= read -r l; do case "$l" in ''|'#'*) ;; *) TARGETS+=("$l");; esac; done < "$SRC/ops/frame/targets.txt"; fi
[ ${#TARGETS[@]} -gt 0 ] || { echo "没有目标：给路径，或写 ops/frame/targets.txt（一行一个）"; exit 2; }
if [ "$APPLY" = 1 ] && git_dirty "$SRC" "${SBASE#$SRC/}"; then
  echo "🔴 本项目的 FRAME 有未提交改动——拒绝分发。**只认已提交的 FRAME**。"; exit 1; fi
rc=0
for T in "${TARGETS[@]}"; do
  [ -d "$T" ] || { echo "🔴 目标不存在：$T"; rc=1; continue; }
  TROLE="$(role_of "$T")"; TBASE="$(base_of "$T" "$TROLE")"
  BLSFX=""; [ -n "${FRAME_TEMPLATE:-}" ] && BLSFX="-$(basename "$FRAME_TEMPLATE")"
  BL="$T/ops/frame/.baseline$BLSFX"
  echo "══════════════════════════════════════════════"
  echo "目标：$T   角色：$TROLE   落点：${TBASE#$T/}"
  if [ "$APPLY" = 1 ] && git_dirty "$T"; then
    echo "🔴 目标工作区有未提交改动——拒绝写。"; rc=1; continue; fi
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
    # 🔴 同一条道理（见上面 sync 那段）：**基线记谁的，决定了以后差异算谁的**。
    # 分发这一侧，adopt 的意思是「**认下目标现在这样**」，所以记**目标**的哈希——
    # 下一轮 th == bh，源改了就正常覆盖。记成源的哈希会让每一份都变成「目标改过」的假冲突。
    if [ "$MODE" = adopt ]; then
      if [ "$ADOPT_MINE" = 1 ]; then echo "$sh $rel" >> "$TMP"
      else [ "$th" != "-" ] && echo "$th $rel" >> "$TMP"; fi
      nS=$((nS+1)); continue; fi
    if [ "$bh" = "-" ]; then nConf=$((nConf+1)); K+=("$rel  (没有基线)"); echo "$th $rel" >> "$TMP"
    elif [ "$th" = "$bh" ]; then nU=$((nU+1)); U+=("$rel")
      [ "$APPLY" = 1 ] && cpn "$s" "$t"; echo "$sh $rel" >> "$TMP"
    else nConf=$((nConf+1)); K+=("$rel  (目标改过)"); echo "$th $rel" >> "$TMP"; fi
  done < <(list_files "$SRC" "$SROLE")

  # ── 根文件映射 map= / patch=：目标那几份是「模板 ＋ 声明式开源专用补丁」──
  nMap=0; nMapSame=0; nMapConf=0; nPatchFail=0; M=(); MC=()
  while IFS= read -r mline; do
    [ -n "$mline" ] || continue
    rootf="${mline%%:*}"; tplrel="${mline#*:}"; srcf="$SRC/$tplrel"
    [ -f "$srcf" ] || { echo "  🔴 map 的源不存在：$tplrel"; rc=1; continue; }
    proj="$(mktemp)"; cp "$srcf" "$proj"
    while IFS= read -r pl; do
      [ -n "$pl" ] || continue
      [ "${pl%%:*}" = "$rootf" ] || continue
      expr="${pl#*:}"; before="$(hs "$proj")"
      sed -i "$expr" "$proj" 2>/dev/null || true
      [ "$(hs "$proj")" = "$before" ] && { nPatchFail=$((nPatchFail+1))
        MC+=("$rootf  🔴 补丁没套上（源改了措辞？要人更新这条补丁）：${expr:0:44}"); }
    done < <(conf_all "$T" patch)
    ph="$(hs "$proj")"; th="$(h "$T/$rootf")"; bh="${TB[ROOT:$rootf]:--}"
    if [ "$ph" = "$th" ]; then nMapSame=$((nMapSame+1)); echo "$ph ROOT:$rootf" >> "$TMP"
    elif [ "$MODE" = adopt ]; then
      # 🔴 和上面同一条道理：adopt 记**目标现在这样**，下一轮 th == bh 才会正常覆盖。
      # 记成「算出来的那份」会让每一份根文件下一轮都变成假冲突（第一版就是这样）。
      nMapSame=$((nMapSame+1)); echo "$th ROOT:$rootf" >> "$TMP"
    elif [ "$th" = "-" ] || [ "$th" = "$bh" ]; then
      nMap=$((nMap+1)); M+=("$rootf  ← $tplrel")
      [ "$APPLY" = 1 ] && cpn "$proj" "$T/$rootf"
      echo "$ph ROOT:$rootf" >> "$TMP"
    else nMapConf=$((nMapConf+1)); MC+=("$rootf  (目标改过或没基线)"); echo "$th ROOT:$rootf" >> "$TMP"; fi
    rm -f "$proj"
  done < <(conf_all "$T" map)

  # 铁律 4：源删了只报告
  if [ -f "$BL" ]; then
    while read -r a b; do case "$a" in ''|'#'*) continue;; esac
      case "$b" in ROOT:*) continue;; esac
      [ -f "$SBASE/$b" ] || { nGone=$((nGone+1)); G+=("$b"); }
    done < "$BL"; fi

  printf '  新建 %-4s 更新 %-4s 一致 %-4s 保留(seed) %-4s 跳过 %-4s\n' $nC $nU $nS $nSeed $nSkip
  printf '  🔴 要人看 %-4s 源已删 %-4s  根文件映射：更新 %s 一致 %s 要人看 %s 补丁失效 %s\n' $nConf $nGone $nMap $nMapSame $nMapConf $nPatchFail
  [ ${#C[@]} -gt 0 ] && { echo "  ── 新建 ──"; printf '    + %s\n' "${C[@]}" | head -20; }
  [ ${#U[@]} -gt 0 ] && { echo "  ── 更新 ──"; printf '    ~ %s\n' "${U[@]}" | head -20; }
  [ ${#M[@]} -gt 0 ] && printf '    ~ %s\n' "${M[@]}"
  [ ${#K[@]} -gt 0 ] && { echo "  ── 🔴 要人看的 ──"; printf '    ! %s\n' "${K[@]}" | head -30; rc=1; }
  [ ${#MC[@]} -gt 0 ] && { printf '    ! %s\n' "${MC[@]}"; rc=1; }
  [ ${#G[@]} -gt 0 ] && { echo "  ── 源已删（🔴 从不自动删，自己确认）──"; printf '    ? %s\n' "${G[@]}" | head -20; }
  if [ "$APPLY" = 1 ] || [ "$MODE" = adopt ]; then
    mkdir -p "$(dirname "$BL")"
    { echo "# 同步自 $SROLE $SRC  commit=$(cd "$SRC" && git rev-parse --short HEAD 2>/dev/null || echo -)  版本=$(ver_read "$SRC" "$SROLE")  $(date +%F)"
      echo "# 一行：<内容sha256> <相对路径>；ROOT:<名> 是根文件映射"
      LC_ALL=C sort -u "$TMP"; } > "$BL"
    echo "  ✅ 基线已记：${BL#$T/}"
  else
    echo "  （dry-run，没写任何东西。要写：--apply；首次建基线：--adopt）"
  fi
  rm -f "$TMP"; unset TB
done
exit $rc
