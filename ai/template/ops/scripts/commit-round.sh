#!/usr/bin/env bash
# commit-round: 审查席一轮拍板完，把这一轮的改动提交到**本地** git。
# 用法：bash ops/scripts/commit-round.sh "<一句话标题>" --seat <席>   [--dry] [-- <只看这些路径…>]
#       审查席代提开发席：bash ops/scripts/commit-round.sh ["<标题>"] --seat 开发席 --by 审查席 --for "T-0010 B-0019"
#         （审查通过那一轮；不给标题就取 ai/state/now.md 第七节代码块的第一行；workflow.md §七之二）
#       存档提交（一段做完、自动检查全绿、还没审）：再加 --unreviewed，标题自动带「未审：」（需求方 2026-10-05）
#       共写文件（信箱 · 归档 · 记忆）：**名字里带本席的自动带上，其余的在 `--` 后点名才提交**（见下「共写文件按文件名分」）
# 退出码 0 = 提交好了（或 --dry 演练通过）；1 = 前置条件不满足（原样退出，什么都没动）；2 = 结构不对。
#
# 【边界，一个字都不许越】
#   · **默认只做 add + commit，不 push。** 推送是需求方的事（他用 SourceTree）——
#     **例外：需求方授权自动推送的项目**，在 `ai/frame-repo.conf` 写 `auto-push=<远端…>`，提交成功后逐个 `git push <远端> <当前分支>`，
#     推不上原样报、不重试、不碰凭据、永不 `--force`（需求方 2026-10-25 在一个项目里授权：「每次提交，你可以顺便推送远端和github远端吗」）。
#   · **永不 amend / rebase / reset / checkout / cherry-pick / force**——那些会改写历史，
#     而 SourceTree 正开着这个仓库，历史被改写它会显示成一团乱麻，恢复要人工。
#   · **永不动 git config**（`core.autocrlf` 这类是需求方 Windows 侧的设置，动了满屏假 diff）。
#   · **永不新建/切换分支**，就在当前分支上提交。
#
# 【SourceTree 安全的四道前置检查】——任何一条不过就原样退出，不是报错，是「现在不该提交」
#   ① `.git/index.lock` 在 → SourceTree 正在操作，**等它做完**，抢锁会让它当场报错；
#      `HEAD.lock` / 当前分支的 ref 锁 / `packed-refs.lock` 在 → 写分支必失败，**报出名字**，确认后由人删
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

# ── 代提：只有一种合法形态（需求方 2026-09-30 定：审查过了由审查席连同开发席的代码一起提交）──
# 开发席不提交（自己写的自己提交＝绕过审查）；它的改动在审查席判「过」/「关闭」那一轮由审查席代提，
# **开发席一份、审查席一份，两次提交**。别的「谁替谁提」一律不开——那会让「提交席」这一栏失去意义。
if [ -n "$BY" ]; then
  case "$BY" in 审|审查|审查席|reviewer) BY=审查席;; *) echo "⛔ --by 只认 审查席（代提只有「审查席代提开发席」这一种）"; exit 2;; esac
  case "$SEAT" in 开|开发|开发席|developer) ;; *) echo "⛔ --by 审查席 只能配 --seat 开发席"; exit 2;; esac
  printf '%s' "$FOR" | grep -qE '(T|B)-[0-9]{4}' || { echo "⛔ 代提要写明是哪几条过了：--for \"T-#### B-####\""; exit 2; }
  if [ -z "$TITLE" ] && [ -f ai/state/now.md ]; then
    TITLE="$(awk '/^## (七|7[.、])/{f=1;next} f&&/^## /{exit} f&&/^```/{c++;next} f&&c==1&&NF{print;exit}' ai/state/now.md)"
    [ -n "$TITLE" ] || { echo "⛔ 没给标题，ai/state/now.md 第七节代码块里也没有一行可抄"; exit 2; }
  fi
fi

# ── 存档提交（需求方 2026-10-05）：开发一段做完、这一段的自动检查与一致性用例全绿、任务里写了自测，
# 审查席不等审查先代提。**历史里要看得出「这一份没审过」**——所以只认「审查席代提开发席」这一种形态，标题前缀由脚本加，不靠人记得写。
# 守门红了照普通提交的规矩（ANYWAY=1 并在提交信息里写明）：巡检里常有别席的红，硬拦等于存档永远提交不了。
if [ "$UNREV" = 1 ]; then
  [ "$BY" = 审查席 ] || { echo "⛔ --unreviewed 只用在审查席代提开发席：--seat 开发席 --by 审查席 --for \"T-####\" --unreviewed"; exit 2; }
  case "$TITLE" in 未审*) ;; *) TITLE="未审：$TITLE";; esac
fi
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

# ── 其余三把提交必用的锁 ──
# 【为什么】原来只查 index.lock。审查席 2026-10-15 实测：上一笔提交留下 `.git/refs/heads/master.lock`，这里放行，
# 脚本跑到最后 update-ref 才 `cannot lock ref` 失败，提示还指着 HEAD.lock 那套。提交要写的锁事先全查，**报出名字和年龄**。
STALE=""
for l in .git/HEAD.lock ".git/refs/heads/$br.lock" .git/packed-refs.lock; do
  [ -e "$l" ] && STALE="$STALE
     $l（$(( ($(date +%s) - $(stat -c %Y "$l")) / 60 )) 分钟没动）"
done
if [ -n "$STALE" ]; then
  echo "⛔ 这几把锁在，提交写分支时一定失败（cannot lock ref）：$STALE"
  echo "   多半是上一次提交（本脚本或 SourceTree）被打断留下的。**先去 SourceTree 确认没有正在进行的操作**，确认了再删它们。"
  echo "   （由需求方或有删除权限的会话删，**这个脚本不替你删**——万一真有操作在跑，删了会毁掉它。）"
  exit 1
fi

# ── 守门红着不许提交 ──
# 「红着就是没做完」是这套方法的基本判据；带着红灯提交，等于把「没做完」写进历史，
# 而且下一个人 clone 下来会以为这是个干净的基线。
# 🔴 **巡检结果可复用**（审查席 2026-09-30 实测：挂载盘上 check-all 约 2 分钟，脚本原来红时还要再跑一遍列红项，
# 加上 git commit 本身，一次调用超过沙箱 180 s 上限被杀、留锁）。check-all 每跑一次都把结果写进 tmp/.check-all.last；
# **20 分钟内的结果直接用**（CHECK_ALL_MAX_AGE 秒可调），过期或没有才现跑。判的是「提交前守门绿不绿」，不是「现跑一遍」。
LAST=tmp/.check-all.last; MAXAGE="${CHECK_ALL_MAX_AGE:-1200}"
if [ -f "$LAST" ] && [ $(( $(date +%s) - $(head -1 "$LAST" | cut -d' ' -f1) )) -le "$MAXAGE" ] 2>/dev/null; then
  GUARD_SRC="沿用 $(( ($(date +%s) - $(head -1 "$LAST" | cut -d' ' -f1)) / 60 )) 分钟前的巡检"
else
  bash ops/verify/check-all.sh >/dev/null 2>&1; GUARD_SRC="现跑"
fi
GUARD="$(grep -aoE 'ALL-(OK|FAIL).*' "$LAST" 2>/dev/null | head -1)"
[ -n "$GUARD" ] || { echo "⛔ 拿不到巡检结果（$LAST 没写出来）"; exit 2; }
GUARD="$GUARD（$GUARD_SRC）"
# 🔴 **红了先不拦，等知道「这次要提交哪些文件」再判**（监督席 2026-10-27 提，需求方转维护席：一笔纯文档提交
# 被另一席自己的任务文件超行数挡住、另一笔被「计划中」的路径挡住——都跟这次提交无关）。判法见下面「守门：只拦本次惹的红」。
GUARD_RED=0
case "$GUARD" in
  ALL-FAIL*)
    if [ "${ANYWAY:-0}" != 1 ]; then GUARD_RED=1
    else GUARD="$GUARD ⚠ 带红提交（ANYWAY=1）"; fi
    ;;
esac

# ── 文件归属：谁的文件谁提交（判据的唯一出处是 ai/rules/layout.md §七 的归属表）──
# 【为什么要这条】旧版一律 `git add -A`，**实测两次把别席同时在改的文件裹进了自己的提交**：
#   · 一次实测：维护席的提交裹走了审查席的 B-0002/T-0034/now.md/收件簿与监督席的报告（24 个文件里 10 个不是它的）；
#   · 另一次：审查席提交时，维护席刚暂存好的 6 个文件差一点被一起带走。
# **提交信息是四席共用的历史，裹错了就等于历史说谎。** 所以：横跨两席以上就停下，让人挑。
# 【精确优先，其次最长前缀】原来按表里的先后取第一个匹配：`product/*` 排在 `product/requirements/requester-profile.md` 前面，
# 那份画像就永远判给审查席，`--seat 监督席` 拒提（监督席 2026-10-17 实测）。现在**表里行的先后不影响结果**：
# 精确路径 > 更长的前缀 > 更短的前缀（`.github/workflows/*` 才能从 `.github/` 一类的大前缀里分出来）。
SEAT_OF_FILE() {  # $1=路径 → 输出 维护席/审查席/开发席/监督席/共写/—
  # 【`ops/scripts/` 里不在 FRAME 清单上的，是项目自己的脚本，归开发席】（需求方 2026-10-29 拍板：发布脚本归维护席时，
  # 开发席每改一次就要发信请维护席复核，两天 4 封）。清单 `ai/frame-manifest.txt` 列的是 FRAME 自带的那几支，仍归维护席。
  case "$1" in ops/scripts/*) if [ -f ai/frame-manifest.txt ] && ! grep -qxF -- "$1" ai/frame-manifest.txt; then echo 开发席; return; fi;; esac
  o="$(awk -v f="$1" '
    /^## / { sec = ($0 ~ /^## (七|7[.、])/); next }   # 只读 §七 那张表：layout.md 别的表第三列也会出现席位名
    !sec { next }
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
        if (star) { sub(/\*$/, "", p); if (index(f, p) == 1 && length(p) > blen) { blen = length(p); best = owner } }
        else if (f == p) { exact = owner; exit }
      }
    }
    END { if (exact != "") print exact; else if (best != "") print best }' ai/rules/layout.md)"
  # 【`ops/` 下归属表没登记、也不在 FRAME 清单上的，同理归开发席】（项目自己的部署、发布配置，例如发布链路的骨架目录；
  # 需求方 2026-10-29 定的是「项目自己的脚本归开发席」，这些和脚本是同一类东西——维护席只管 FRAME 的规矩，不管产品的发布链路）。
  if [ -z "$o" ]; then case "$1" in ops/*) if [ -f ai/frame-manifest.txt ] && ! grep -qxF -- "$1" ai/frame-manifest.txt; then o=开发席; fi;; esac; fi
  [ -n "$o" ] && printf '%s\n' "$o"
}
OWNERSHIP_SPLIT() {   # $1=文件清单（每行一个）→ 打印「席位: 文件…」
  printf '%s\n' "$1" | grep . | while IFS= read -r f; do
    o=$(SEAT_OF_FILE "$f"); echo "${o:-未登记}|$f"
  done
}

# --dry **绝不碰暂存区**：需求方可能已经在 SourceTree 里挑好了要暂存哪些，
# 先 add -A 再 reset 会把他挑的结果抹掉（这条是实跑时踩出来的）。
# 🔴 **只扫该扫的路径**（审查席 2026-09-30 实测：挂载盘上全仓 `git diff --name-only` 超过 175 s，按包逐个 0–21 s）。
# 给了 `-- <路径…>` 就只看那些；给了 --seat 就只看归属表里**这一席与共写**的路径（它能提交的本来就只有这些）；
# 两样都没给才全仓扫。代价：--seat 时「留给别席的改动」只数得到这个范围里的。
SCOPE=()
if [ "${#NARROW[@]}" -gt 0 ]; then SCOPE=("${NARROW[@]}")
elif [ -n "$SEAT" ] && [ "$ALLSEATS" != 1 ]; then
  case "$SEAT" in 维|维护|维护席|maintainer) S0=维护席;; 审|审查|审查席|reviewer) S0=审查席;; 开|开发|开发席|developer) S0=开发席;;
    监|监督|监督席|supervisor) S0=监督席;; 研|研究|研究席|researcher) S0=研究席;; *) S0="$SEAT";; esac
  while IFS= read -r ps; do [ -n "$ps" ] && SCOPE+=("$ps"); done < <(awk -v s="$S0" -F'|' '
    /^## / { sec = ($0 ~ /^## (七|7[.、])/); next }   # 只读 §七 那张表：layout.md 别的表第三列也会出现席位名
    !sec { next }
    /^\|/ && !/^\|---/ { o=$3; if (o !~ s && o !~ /共写/) next
      n=split($2, ps, "·"); for (i=1;i<=n;i++){ p=ps[i]; gsub(/[` ]/,"",p); gsub(/^\*\*|\*\*$/,"",p); if (p!="") print p } }' ai/rules/layout.md | sort -u)
fi
if [ "$DRY" = 1 ]; then
  D_STAT="$(G diff HEAD --shortstat -- "${SCOPE[@]}" | sed 's/^ *//')"
  # 【为什么要带上未跟踪文件】`git diff` **看不见新建的文件**，于是本轮新开的 `T-0038` 在 --dry 里
  # 永远捞不到（审查席 2026-09-15 实测报来）。真提交时 `add -A` 会把它纳入，**只有演练是瞎的**——
  # 演练和真提交说法不一致，比不演练更糟。
  D_FILES="$({ G diff HEAD --name-only -- "${SCOPE[@]}"; G ls-files --others --exclude-standard -- "${SCOPE[@]}"; } | grep . | sort -u)"
  [ -z "$D_FILES" ] && { echo "没有要提交的改动（工作区是干净的）。"; exit 0; }
  CAND="$D_FILES"
else
  CAND="$({ G diff HEAD --name-only -- "${SCOPE[@]}"; G ls-files --others --exclude-standard -- "${SCOPE[@]}"; } | grep . | sort -u)"
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
# 🔴 **共写文件按文件名分**（需求方 2026-10-05 定）。原来 --seat 把「共写」文件**整份**算成本席的，
# 于是别席在信箱 / 归档 / 记忆里还没提交的改动被一起带走、署到本席名下（实测两次：内容没丢，历史署名错）。
# 现在：**名字里带本席的自动带上**——自己发信的投递口 `to-*/from-<本席>.md`、自己收信的 `to-<本席>/`、
# 自己的归档 `archive/<本席>-*`、自己的座位记忆 `seat-<本席>.md`；**其余共写文件**（`ai/memory.md` 这类分不出谁改的）
# **只有在命令后 `-- <路径>` 点名才带**，没点名的列出来、留在工作区。
# 拦不住的一种：同一份投递口两席同时在改（发信人加行、收信人移行），谁先提交谁带走——少见，提交前看一眼 --dry。
SHARED_LEFT=""
NOTE_SHARED() {
  [ -n "$SHARED_LEFT" ] || return 0
  echo "ℹ️  有 $(printf '%s\n' "$SHARED_LEFT" | grep -c .) 个共写文件改过、但名字里不带 $SEAT、也没点名，**这次没带**（是你改的就再跑一次，在命令后加 -- <路径…>）："
  printf '%s\n' "$SHARED_LEFT" | sed 's/^/     /'
}
if [ -n "$SEAT" ] && [ "$ALLSEATS" != 1 ]; then
  case "$SEAT" in 维护席) SEAT_EN=maintainer;; 审查席) SEAT_EN=reviewer;; 开发席) SEAT_EN=developer;; 监督席) SEAT_EN=supervisor;; 研究席) SEAT_EN=researcher;; *) SEAT_EN="-";; esac
  SHARED_AWK='function by_name(p) { return (p ~ ("^ai/mail/to-[^/]+/from-" en "[.]md$") || index(p, "ai/mail/to-" en "/") == 1 || index(p, "ai/mail/archive/" en "-") == 1 || p == ("ai/memory-archive/seat-" en ".md")) }'
  MINE="$(printf '%s\n' "$SPLIT" | awk -F'|' -v s="$SEAT" -v en="$SEAT_EN" -v named="${#NARROW[@]}" "$SHARED_AWK"'
    $1==s {print $2; next} $1=="共写" && (named > 0 || by_name($2)) {print $2}')"
  SHARED_LEFT="$(printf '%s\n' "$SPLIT" | awk -F'|' -v en="$SEAT_EN" -v named="${#NARROW[@]}" "$SHARED_AWK"'
    $1=="共写" && !(named > 0 || by_name($2)) {print $2}')"
  [ -z "$MINE" ] && { echo "⛔ 这一轮没有属于 $SEAT 的改动（归属表：ai/rules/layout.md §七）。"; NOTE_SHARED; exit 1; }
  OTHERS="$(printf '%s\n' "$SPLIT" | awk -F'|' -v s="$SEAT" '$1!=s && $1!="共写" {print $1"|"$2}')"
fi
# 给了 `-- <路径>` 又没按席挑出文件（--all-seats）：就只提交这些路径下的改动，**不许退化成全仓 add -A**
[ -z "$MINE" ] && [ "${#NARROW[@]}" -gt 0 ] && MINE="$CAND"

# ── 守门：只拦本次惹的红 ──
# 红项明细在 tmp/.check-all.detail（check-all 每次都存）。**明细里点到了本次要提交的任何一个文件 → 拦**；
# 都没点到 → 是别席或别处的红，照常提交，红项写进提交信息。明细不在（旧版巡检、或刚好被清掉）→ 判不了，照旧拦。
# 🔴 **每轮收尾必须全量绿**的规矩不变——这里放过的只是「与本次无关」的红，它们照样躺在巡检里等归属席修。
if [ "$GUARD_RED" = 1 ]; then
  COMMITS="${MINE:-$CAND}"; DET=tmp/.check-all.detail; HIT=""
  # 【只看「发现」，不看提示语】每条红项在判据行（`*-FAIL`）之后常跟一句「改法」，里面也写路径
  # （行数预算那条就写着「要在 ai/rules/maintenance-log.md 记一条」——实测把维护记录误判成「本次惹的红」）。
  # 所以每块只取 `── 名字 ──` 之后、第一行 `-FAIL` 之前的那些行。
  FIND="$(mktemp "${TMPDIR:-/tmp}/cr_find.XXXXXX")"
  # 再收窄一层（2026-10-29 实测）：判据行之前也有说明行——行数预算会打印「固定内容＝ CLAUDE.md + laws.md …」，
  # 把要提交的 CLAUDE.md 误判成本次惹的红。所以只认**发现行**：带 ✗ 的、断链行、路径检查的 `── ./文件` 行，
  # 以及紧跟其后、缩进 5 格以上的续行（版本守门列文件就这么写）。
  [ -f "$DET" ] && awk '/^── .* ──$/ {k=1; c=0; next} /-FAIL/ {k=0} !k {next}
      /✗|^ *x  |^(断链|锚点断链|broken)|^── \.\// {print; c=1; next}
      c && /^     / {print; next} {c=0}' "$DET" > "$FIND"
  [ -f "$DET" ] && HIT="$(printf '%s\n' "$COMMITS" | grep . | while IFS= read -r f; do grep -aqF -- "$f" "$FIND" && echo "$f"; done)"
  rm -f "$FIND" 2>/dev/null
  if [ ! -f "$DET" ] || [ -n "$HIT" ]; then
    echo "⛔ 守门有红的：$GUARD"
    grep -a '❌' "$LAST" | sed 's/^/   /'
    if [ -n "$HIT" ]; then echo "   红项里点到了这次要提交的文件："; printf '%s\n' "$HIT" | sed 's/^/     /'
    else echo "   （没有红项明细 $DET，判不了红的是谁——重跑一次 bash ops/verify/check-all.sh 再提交）"; fi
    echo "   先修绿再提交。**确实要带着红灯提交**（例如这一轮就是为了修它）："
    echo "   ANYWAY=1 bash $0 \"<标题>\"   —— 提交信息里会写明带红提交。"
    exit 1
  fi
  REDS="$(grep -a '❌' "$LAST" | sed -E 's/^ *❌ *//; s/  +.*//' | awk '{printf "%s%s", (NR>1 ? "、" : ""), $0}')"
  echo "ℹ️  守门有红（$REDS），但红项里没有点到这次要提交的文件，照常提交；红项归谁按 layout.md §七，**每轮收尾仍要全绿**。"
  GUARD="$GUARD ⚠ 红项与本次提交无关（$REDS），没拦"
fi

if [ "$DRY" != 1 ]; then
  if [ -n "$MINE" ]; then
    # 只暂存自己的那几份；**不动别席已经暂存的东西**（不许 reset，SourceTree 安全五不许）
    set --; while IFS= read -r f; do [ -n "$f" ] && set -- "$@" "$f"; done <<< "$(printf '%s\n' "$MINE" | grep .)"
    GIT_LITERAL_PATHSPECS=1 G add -A -- "$@"
  else
    G add -A
  fi
  if [ -n "$MINE" ]; then CHK=(-- "$@"); else CHK=(); fi
  if GIT_LITERAL_PATHSPECS=1 G diff --cached --quiet HEAD "${CHK[@]}"; then
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
# 代提时开发席的文件多半在 src/ 下，文件名里没有任务号——用 --for 给的号（那才是「这次过了哪几条」）
if [ -n "$BY" ]; then
  tasks=$(printf '%s\n' "$FOR $tasks" | grep -oE 'T-[0-9]{4}' | sort -u | paste -sd' ' -)
  bugs=$(printf '%s\n' "$FOR $bugs" | grep -oE 'B-[0-9]{4}' | sort -u | paste -sd' ' -)
fi
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

BYNOTE=""; [ -n "$BY" ] && BYNOTE="（$BY 代提：审查通过后一并提交；对应 $FOR）"
[ "$UNREV" = 1 ] && BYNOTE="（$BY 代提：**存档提交，还没审查**；对应 $FOR）"
PUSHNOTE="**未推送**，请在 SourceTree 里确认后 push。"; [ -n "$AUTOPUSH" ] && PUSHNOTE="提交后按 ai/frame-repo.conf 自动推送到：$AUTOPUSH"
MSG=$(cat <<EOM
$TITLE

日期: $(date '+%Y-%m-%d %H:%M')
范围: $files 个文件（$stat）
任务: ${tasks:-—}
bug:  ${bugs:-—}
决策: ${ads:-—}
守门: $GUARD
提交席: ${SEAT:-未指定（--all-seats 或全仓只有一席的改动）}$BYNOTE${OTHERS:+
留给别席的改动（本次没有提交）: $(printf '%s\n' "$OTHERS" | awk -F"|" '{c[$1]++} END {for (k in c) printf "%s %d 个 · ", k, c[k]}' | sed 's/ · $//')}

本次提交由 AI 会话（审查席 / 维护席）自动生成；$PUSHNOTE

Co-Authored-By: Claude <noreply@anthropic.com>
EOM
)

if [ "$DRY" = 1 ]; then
  echo "── 演练，没有提交，**暂存区一个字都没动** ──"; echo "$MSG"; echo; echo "（「范围」那行的文件数就是它，同一个来源）"; NOTE_SHARED; exit 0
fi

# 🔴 **真提交走底层命令，不用 `git commit`**（审查席 2026-09-30 实测：挂载盘上 `git commit` 连续三次超过 175 s 被杀，
# 留下 index.lock / HEAD.lock 挡住 SourceTree；它慢在提交前刷新整个索引、逐个 stat 工作区。底层四步只碰这几份文件，1–10 s）：
#   临时索引从 HEAD 读起 → 只把本次的文件加进去 → write-tree → commit-tree → update-ref（带旧值：比较后交换，
#   别人在这期间提交过就失败、什么都不改）。**用临时索引**是为了不把别人在 SourceTree 里暂存的东西带进来
#   （原来 `git commit -- <路径>` 的 --only 语义，就是这个意思）。
MSGF="$(mktemp "${TMPDIR:-/tmp}/cr_msg.XXXXXX")" && TIDX="$(mktemp "${TMPDIR:-/tmp}/cr_idx.XXXXXX")" || { echo "⛔ 建不了临时文件，没有提交。"; exit 1; }
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

# ── 收尾：本脚本自己留下的锁与临时对象（**成功和失败都收**）──
# 沙箱默认没有删除权限时，git 建得出锁、删不掉（memory 类型 6）。**只动这次运行期间新出现的**（mtime ≥ 开始时刻），
# 更早的锁可能是 SourceTree 的，不碰。删不掉就明说，别让需求方下一次在 SourceTree 里撞上。
# 【为什么用 find 不用清单】原来只清写死的五个名字、且只在成功时清；审查席 2026-10-15 实测一次提交后留下
# `.git/refs/heads/master.lock`，下一笔两次 `cannot lock ref`。git 会建哪些锁不靠清单猜，**按「本次新出现的 *.lock」一把扫**。
# 【坑】`-newermt` 是严格大于，同一秒建的锁会漏，所以从 START-1 算起。
left=""; tmpn=0
while IFS= read -r l; do
  [ -n "$l" ] || continue
  rm -f "$l" 2>/dev/null || left="$left $l"
done < <(find .git -path .git/objects -prune -o -name '*.lock' -newermt "@$((START-1))" -print 2>/dev/null
         find .git/objects -maxdepth 1 -name '*.lock' -newermt "@$((START-1))" 2>/dev/null)
while IFS= read -r t; do rm -f "$t" 2>/dev/null || tmpn=$((tmpn+1)); done < <(find .git/objects -name 'tmp_obj_*' -newermt "@$((START-1))" 2>/dev/null)
if [ "$ok" != 1 ]; then
  echo "提交失败，分支没动（$br 仍是 ${OLD:0:7}）。"
  [ -n "$left" ] && echo "⚠️  本次留下的锁删不掉：$left —— 申请一次这个文件夹的删除权限再删（它们是这次运行建的）"
  OLDL="$(find .git -path .git/objects -prune -o -name '*.lock' -print 2>/dev/null)"
  [ -n "$OLDL" ] && { echo "   仓库里还有这些锁（不是这次建的，多半就是失败的原因；先确认 SourceTree 没在操作再删）："; printf '%s\n' "$OLDL" | sed 's/^/     /'; }
  exit 1
fi
[ -n "$left" ] && echo "⚠️  提交成功，但删不掉本次留下的锁：$left —— 申请一次这个文件夹的删除权限再删（它们是这次运行建的）"
[ "$tmpn" -gt 0 ] && echo "⚠️  还有 $tmpn 个本次留下的 .git/objects/**/tmp_obj_*（无害，有删除权限时顺手删）"
echo "✅ 已提交到本地分支 $br：$(G rev-parse --short HEAD)"
echo "   $TITLE"
if [ -n "$AUTOPUSH" ]; then
  # 自动推送：需求方授权的项目才有 auto-push=；逐个远端推当前分支，**不重试、不碰凭据、永不 --force**
  for r in $AUTOPUSH; do
    po="$(mktemp "${TMPDIR:-/tmp}/cr_push.XXXXXX")"
    if { command -v timeout >/dev/null 2>&1 && timeout "${PUSH_TIMEOUT:-150}" git push "$r" "$br" >"$po" 2>&1; } \
       || { ! command -v timeout >/dev/null 2>&1 && git push "$r" "$br" >"$po" 2>&1; }; then
      echo "   ⬆️  已推送 $r/$br"
    else
      echo "   ⚠️  推送 $r 失败（不重试、不改凭据；提交已在本地）："; sed 's/^/        /' "$po" | tail -6
    fi
    rm -f "$po" 2>/dev/null
  done
  echo "   （用时 $(( $(date +%s) - START )) 秒）"
else
  echo "   **没有推送** —— 去 SourceTree 看一眼再 push。（用时 $(( $(date +%s) - START )) 秒）"
fi
NOTE_SHARED
