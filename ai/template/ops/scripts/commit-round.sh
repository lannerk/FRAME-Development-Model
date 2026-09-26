#!/usr/bin/env bash
# commit-round: 审查席一轮拍板完，把这一轮的改动提交到**本地** git。
# 用法：bash ops/scripts/commit-round.sh "<一句话标题>"   [--dry]
# 退出码 0 = 提交好了（或 --dry 演练通过）；1 = 前置条件不满足（原样退出，什么都没动）；2 = 结构不对。
#
# 【边界，一个字都不许越】
#   · **只做 add + commit。永不 push。** 推送是需求方的事（他用 SourceTree）。
#   · **永不 amend / rebase / reset / checkout / cherry-pick / force**——那些会改写历史，
#     而 SourceTree 正开着这个仓库，历史被改写它会显示成一团乱麻，恢复要人工。
#   · **永不动 git config**（`core.autocrlf` 这类是需求方 Windows 侧的设置，动了满屏假 diff）。
#   · **永不新建/切换分支**，就在当前分支上提交。
#
# 【SourceTree 安全的四道前置检查】——任何一条不过就原样退出，不是报错，是「现在不该提交」
#   ① `.git/index.lock` 在 → SourceTree 正在操作，**等它做完**，抢锁会让它当场报错
#   ② 正在 merge / rebase / cherry-pick → 这时提交会把半成品合进去
#   ③ HEAD 游离（detached）→ 提交会掉进没有分支的地方，SourceTree 里看不见
#   ④ 没有可提交的改动 → 不造空提交
#
# 【为什么用 -c core.fileMode=false】这个脚本从挂载盘跑，Linux 侧看到的可执行位和
# Windows 侧不一样，不关掉会把一堆「mode change 100644 → 100755」塞进提交，
# 那是纯噪音，而且会让 SourceTree 的 diff 满屏飘红。
set -u
# 🔴 **只读的 git 调用一律不许建 index.lock**（监督席 2026-09-24 报的根因，实测过两次）：
# Cowork 本机工作区默认**没有删除权限**，而 `git status` / `git diff` 这类只读调用会顺手刷新索引、
# **建得出 `.git/index.lock` 却删不掉**——于是守门跑一次就在需求方的仓库里留一把死锁，
# 下一次提交（包括他自己在 SourceTree 里的）全被挡住。判的是「**别在别人的仓库里留锁**」，
# 不是「脚本能不能跑通」。`GIT_OPTIONAL_LOCKS=0` 让 git 跳过这类可选的锁；真正要写的 `add`/`commit`
# 照常拿它自己的锁，不受影响。
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
[ -d .git ] || { echo "这里不是 git 仓库根"; exit 2; }

# 身份：这台机器（挂载盘 / 云端容器）没有 git 全局身份，需求方的身份在 Windows 侧的 global 配置里，
# 这边看不见。**不写进 .git/config**（那会覆盖他的全局身份，而且属于「动 git config」）——
# 改成从**上一条提交的作者**取，用 `-c` 临时传进去。这样历史里的作者和他平时提交的一模一样，
# SourceTree 也不会多出一个陌生作者。取不到就明说，让他自己定。
AUTH_N="$(git log -1 --pretty='%an' 2>/dev/null || true)"
AUTH_E="$(git log -1 --pretty='%ae' 2>/dev/null || true)"
G() {
  if [ -n "$AUTH_N" ] && [ -n "$AUTH_E" ]; then
    git -c core.fileMode=false -c core.quotepath=false -c user.name="$AUTH_N" -c user.email="$AUTH_E" "$@"
  else
    git -c core.fileMode=false -c core.quotepath=false "$@"
  fi
}

# ── 前置检查 ──
if [ -f .git/index.lock ]; then
  age=$(( $(date +%s) - $(stat -c %Y .git/index.lock) ))
  sz=$(stat -c %s .git/index.lock)
  echo "⛔ .git/index.lock 在 —— 有 git 正在操作这个仓库，现在提交会让它出错。"
  if [ "$sz" -eq 0 ] && [ "$age" -gt 600 ]; then
    echo "   不过这个锁是 **0 字节、已经 $((age/60)) 分钟没动**了，像是上一次 git 没收尾留下的陈旧锁。"
    echo "   **先去 SourceTree 确认没有正在进行的操作**，确认了再删：rm .git/index.lock"
    echo "   （由需求方或开发席删，**这个脚本不替你删**——万一真有操作在跑，删了会毁掉它。）"
  else
    echo "   等它做完再跑。**不要删那个锁文件。**"
  fi
  exit 1
fi
for m in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
  [ -e ".git/$m" ] && { echo "⛔ 仓库处在未完成的 $m 状态，先在 SourceTree 里收尾。"; exit 1; }
done
br=$(G symbolic-ref --quiet --short HEAD || true)
[ -z "$br" ] && { echo "⛔ HEAD 是游离状态，不在任何分支上。先切回分支。"; exit 1; }

# ── 守门红着不许提交 ──
# 「红着就是没做完」是这套方法的基本判据；带着红灯提交，等于把「没做完」写进历史，
# 而且下一个人 clone 下来会以为这是个干净的基线。
GUARD="$(bash ops/verify/check-all.sh 2>/dev/null | grep -oE 'ALL-(OK|FAIL).*' | head -1)"
case "$GUARD" in
  ALL-FAIL*)
    if [ "${ANYWAY:-0}" != 1 ]; then
      echo "⛔ 守门有红的：$GUARD"
      bash ops/verify/check-all.sh 2>/dev/null | grep '❌' | sed 's/^/   /'
      echo "   先修绿再提交。**确实要带着红灯提交**（例如这一轮就是为了修它）："
      echo "   ANYWAY=1 bash $0 \"<标题>\"   —— 提交信息里会写明带红提交。"
      exit 1
    fi
    GUARD="$GUARD ⚠ 带红提交（ANYWAY=1）"
    ;;
esac

# ── 文件归属：谁的文件谁提交（判据的唯一出处是 ai/rules/layout.md §七 的归属表）──
# 【为什么要这条】旧版一律 `git add -A`，**实测两次把别席同时在改的文件裹进了自己的提交**：
#   · 一次实测：维护席的提交裹走了审查席的 B-0002/T-0034/now.md/收件簿与监督席的报告（24 个文件里 10 个不是它的）；
#   · 另一次：审查席提交时，维护席刚暂存好的 6 个文件差一点被一起带走。
# **提交信息是四席共用的历史，裹错了就等于历史说谎。** 所以：横跨两席以上就停下，让人挑。
SEAT_OF_FILE() {  # $1=路径 → 输出 维护席/审查席/开发席/监督席/共写/—
  awk -v f="$1" '
    /^\|/ {
      line=$0
      if (line ~ /^\|---/) next
      n=split(line, c, "|")
      if (n < 3) next
      paths=c[2]; owner=c[3]
      gsub(/^[ \t]+|[ \t]+$/, "", owner)
      if (owner !~ /(维护席|审查席|开发席|监督席|研究席|共写)/) next
      # 只留席位那个词：表里写的是「**共写**（四席都能写）」这类，带括号说明。
      # 【坑】原来整段输出，于是 `$1=="共写"` 永远不成立，共写文件被算成「别席的」。
      if (owner ~ /共写/) owner="共写"
      else if (owner ~ /维护席/) owner="维护席"
      else if (owner ~ /审查席/) owner="审查席"
      else if (owner ~ /开发席/) owner="开发席"
      else if (owner ~ /监督席/) owner="监督席"
      else if (owner ~ /研究席/) owner="研究席"  # R&D 线的编外座位，只写 ai/RandD/
      m=split(paths, ps, "·")
      for (i=1; i<=m; i++) {
        p=ps[i]
        gsub(/[` ]/, "", p)          # 【坑】这里原来把 * 也一起删了，于是通配行全变成精确匹配、全都对不上
        gsub(/^\*\*|\*\*$/, "", p)   # 去掉加粗标记，但**留下末尾的通配 ***
        if (p == "") continue
        star = (p ~ /\*$/)
        if (star) { sub(/\*$/, "", p); if (index(f, p) == 1) { print owner; exit } }
        else if (f == p) { print owner; exit }
      }
    }' ai/rules/layout.md
}
OWNERSHIP_SPLIT() {   # $1=文件清单（每行一个）→ 打印「席位: 文件…」
  printf '%s\n' "$1" | grep . | while IFS= read -r f; do
    o=$(SEAT_OF_FILE "$f"); echo "${o:-未登记}|$f"
  done
}

# --dry **绝不碰暂存区**：需求方可能已经在 SourceTree 里挑好了要暂存哪些，
# 先 add -A 再 reset 会把他挑的结果抹掉（这条是实跑时踩出来的）。
if [ "$DRY" = 1 ]; then
  D_STAT="$(G diff HEAD --shortstat | sed 's/^ *//')"
  # 【为什么要带上未跟踪文件】`git diff` **看不见新建的文件**，于是本轮新开的 `T-0038` 在 --dry 里
  # 永远捞不到（审查席 2026-09-15 实测报来）。真提交时 `add -A` 会把它纳入，**只有演练是瞎的**——
  # 演练和真提交说法不一致，比不演练更糟。
  D_FILES="$({ G diff HEAD --name-only; G ls-files --others --exclude-standard; } | grep . | sort -u)"
  [ -z "$D_FILES" ] && { echo "没有要提交的改动（工作区是干净的）。"; exit 0; }
  CAND="$D_FILES"
else
  CAND="$({ G diff HEAD --name-only; G ls-files --others --exclude-standard; } | grep . | sort -u)"
  [ -z "$CAND" ] && { echo "没有要提交的改动（工作区是干净的）。"; exit 0; }
fi

# ── 越界拦截 ──
SPLIT="$(OWNERSHIP_SPLIT "$CAND")"
SEATS_TOUCHED="$(printf '%s\n' "$SPLIT" | cut -d'|' -f1 | grep -v '^共写$' | sort -u | grep . || true)"
NSEATS="$(printf '%s\n' "$SEATS_TOUCHED" | grep -c . || true)"
MINE=""
if [ -n "$SEAT" ]; then
  case "$SEAT" in
    维|维护|维护席|maintainer) SEAT=维护席;;
    审|审查|审查席|reviewer)  SEAT=审查席;;
    开|开发|开发席|developer) SEAT=开发席;;
    监|监督|监督席|supervisor) SEAT=监督席;;
    研|研究|研究席|researcher) SEAT=研究席;;
    *) echo "⛔ --seat 只认：维护席 / 审查席 / 开发席 / 监督席 / 研究席（也可写 maintainer / reviewer / developer / supervisor / researcher）"; exit 2;;
  esac
fi
if [ "$ALLSEATS" != 1 ] && [ "$NSEATS" -gt 1 ] && [ -z "$SEAT" ]; then
  echo "⛔ 这一轮的改动**横跨 $NSEATS 席**，不知道该用谁的名义提交（归属表：ai/rules/layout.md §七）："
  printf '%s\n' "$SPLIT" | sort | awk -F'|' '{printf "   %-8s %s\n", $1, $2}'
  echo
  echo "   只提交自己的：bash ops/scripts/commit-round.sh \"<标题>\" --seat 维护席"
  echo "   确实要一起提交（比如需求方让你代提）：加 --all-seats，提交信息里会写明。"
  echo "   【为什么要拦】提交信息是四席共用的历史，裹走别席的改动＝历史说谎（实测两次，见 layout.md §七）。"
  exit 1
fi
if [ -n "$SEAT" ] && [ "$ALLSEATS" != 1 ]; then
  MINE="$(printf '%s\n' "$SPLIT" | awk -F'|' -v s="$SEAT" '$1==s || $1=="共写" {print $2}')"
  [ -z "$MINE" ] && { echo "⛔ 这一轮没有属于 $SEAT 的改动（归属表：ai/rules/layout.md §七）。"; exit 1; }
  OTHERS="$(printf '%s\n' "$SPLIT" | awk -F'|' -v s="$SEAT" '$1!=s && $1!="共写" {print $1"|"$2}')"
fi

if [ "$DRY" != 1 ]; then
  if [ -n "$MINE" ]; then
    # 只暂存自己的那几份；**不动别席已经暂存的东西**（不许 reset，SourceTree 安全五不许）
    printf '%s\n' "$MINE" | grep . | while IFS= read -r f; do G add -- "$f"; done
  else
    G add -A
  fi
  if G diff --cached --quiet; then
    echo "没有要提交的改动（工作区是干净的）。"; exit 0
  fi
fi

# ── 提交信息：标题 + 这一轮到底动了什么 ──
if [ "$DRY" = 1 ]; then
  names="${MINE:-$D_FILES}"; diffsrc="HEAD"
else
  names="${MINE:-$(G diff --cached --name-only)}"; diffsrc="--cached"
fi
# 【为什么 stat 也要限定】不限定的话「范围」会报全仓的 14 files changed，而实际提交只有 5 个，
# 审查席 2026-09-15 报过「两个文件数对不上」，**限定之后两个数永远同源**。
if [ "$DRY" = 1 ]; then base=HEAD; else base=--cached; fi
if [ -n "$MINE" ]; then
  # xargs 起的是子进程，看不到 shell 函数 G —— 第一版就这么写，直接 `xargs: G: No such file or directory`。
  # 改成把清单塞进数组再一次性传给 G。
  set --
  while IFS= read -r f; do [ -n "$f" ] && set -- "$@" "$f"; done <<< "$(printf '%s\n' "$MINE" | grep .)"
  stat=$(G diff "$base" --shortstat -- "$@" | sed 's/^ *//')
else
  stat=$(G diff "$base" --shortstat | sed 's/^ *//')
fi
[ -z "$stat" ] && stat="无行级差异（全是新建文件）"
# 新建（未跟踪）的那几个不在 shortstat 里，单独报一个数，**两个数加起来就是「范围」那个文件数**
newn=$(G ls-files --others --exclude-standard | grep -c . || true)
if [ -n "$MINE" ]; then
  newn=$(comm -12 <(printf '%s\n' "$MINE" | grep . | LC_ALL=C sort) <(G ls-files --others --exclude-standard | LC_ALL=C sort) | grep -c . || true)
fi
[ "${newn:-0}" -gt 0 ] && stat="$stat；其中新建 $newn 个"
files=$(printf '%s\n' "$names" | grep -c .)
tasks=$(printf '%s\n' "$names" | grep -oE 'T-[0-9]{4}' | sort -u | paste -sd' ' -)
bugs=$(printf '%s\n' "$names"  | grep -oE 'B-[0-9]{4}' | sort -u | paste -sd' ' -)
# 【AD 编号：判「这一轮定了什么」，不判「正文里提到了什么」】
# 旧判据 `^\+.*\bAD[0-9]{3,4}\b` 捞的是文本影子，审查席 2026-09-15 实测报来三种假阳：
#   ① diff 的 `+++ b/ai/decisions/AD0501-0600.md` 这一行，把**号段文件名**拆成 AD0501 / AD600；
#   ② 正文里**引用**旧决策（`依据 AD443`）；
#   ③ `ai/decisions/index.md` 里「**下一个可用编号** AD539」——那是还没用的号。
# 新判据：只看 `ai/decisions/AD####-####.md` 的**新增表格行**，且必须是行首那一格就是 AD 号
# （`| AD538 | …`）——**那才是「这一轮定了什么」**。宁可漏捞：多捞会让提交信息说谎。
ads=$(G diff $diffsrc -- 'ai/decisions/AD[0-9]*-[0-9]*.md' \
      | grep -E '^\+\|[[:space:]]*(\*\*)?AD[0-9]{3,4}(\*\*)?[[:space:]]*\|' \
      | grep -oE 'AD[0-9]{3,4}' | sort -u | head -12 | paste -sd' ' -)
# 新建的决策号段文件（整份新增）在 diff 里没有「+| ADxxx |」的上下文差异，单独兜一次
if [ -z "$ads" ]; then
  ads=$(printf '%s\n' "$names" | grep -E '^ai/decisions/AD[0-9]+-[0-9]+\.md$' \
        | while IFS= read -r f; do [ -f "$f" ] && grep -oE '^\|[[:space:]]*(\*\*)?AD[0-9]{3,4}' "$f" | grep -oE 'AD[0-9]{3,4}'; done \
        | sort -u | head -12 | paste -sd' ' -)
fi
[ -z "$TITLE" ] && TITLE="第 $(date '+%m%d') 轮改动（$files 个文件）"

MSG=$(cat <<EOM
$TITLE

日期: $(date '+%Y-%m-%d %H:%M')
范围: $files 个文件（$stat）
任务: ${tasks:-—}
bug:  ${bugs:-—}
决策: ${ads:-—}
守门: $GUARD
提交席: ${SEAT:-未指定（--all-seats 或全仓只有一席的改动）}${OTHERS:+
留给别席的改动（本次没有提交）: $(printf '%s\n' "$OTHERS" | awk -F"|" '{c[$1]++} END {for (k in c) printf "%s %d 个 · ", k, c[k]}' | sed 's/ · $//')}

本次提交由 AI 会话（审查席 / 维护席）自动生成；**未推送**，请在 SourceTree 里确认后 push。

Co-Authored-By: Claude <noreply@anthropic.com>
EOM
)

if [ "$DRY" = 1 ]; then
  echo "── 演练，没有提交，**暂存区一个字都没动** ──"; echo "$MSG"; echo; echo "（「范围」那行的文件数就是它，同一个来源）"; exit 0
fi

if [ -n "$MINE" ]; then
  # **路径限定提交**：别席可能已经在 SourceTree 里暂存了东西，无路径的 commit 会把它们一起提交。
  printf '%s\n' "$MINE" | grep . > /tmp/.cr_mine.$$ || true
  # shellcheck disable=SC2046
  G commit -q -m "$MSG" -- $(tr '\n' ' ' < /tmp/.cr_mine.$$)
  rm -f /tmp/.cr_mine.$$
else
  G commit -q -m "$MSG"
fi || { echo "提交失败，什么都没改。"; exit 1; }
echo "✅ 已提交到本地分支 $br：$(G rev-parse --short HEAD)"
echo "   $TITLE"
echo "   **没有推送** —— 去 SourceTree 看一眼再 push。"
