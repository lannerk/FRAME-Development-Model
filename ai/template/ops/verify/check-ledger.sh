#!/usr/bin/env bash
# check-ledger: 台账自身对不对得上 —— 字段、双写、索引与实体、孤儿。
# 用法：bash ops/verify/check-ledger.sh
# 退出码 0 = 对得上；1 = 有对不上的；2 = 结构不对。
#
# 【为什么要这条】监督席体检指出：任务模板要求的字段，30 条里 28 条缺；
# 「改状态要同时改两处」写了规矩、**没有任何东西在看**（当时确实 0 处不一致，
# 但那是靠纪律，不是靠守门——纪律会累）。
#
# 它判四件，都是「要保的那件事」本身，不是文本影子：
#   ① 任务文件头**该有的字段在不在**（判有没有那一行，不判文件里出没出现那几个字）；
#   ② **状态双写一致**：任务文件头的状态 vs 索引表里那一行的状态；
#   ③ **索引与实体对得上**：索引里列的文件存不存在、目录里的文件在不在索引里；
#   ④ **孤儿**：`ai/` 根下不该有散件。
set -u
# 🔴 **只读的 git 调用一律不许建 index.lock**（监督席 2026-09-24 报的根因，实测过两次）：
# Cowork 本机工作区默认**没有删除权限**，而 `git status` / `git diff` 这类只读调用会顺手刷新索引、
# **建得出 `.git/index.lock` 却删不掉**——于是守门跑一次就在需求方的仓库里留一把死锁，
# 下一次提交（包括他自己在 SourceTree 里的）全被挡住。判的是「**别在别人的仓库里留锁**」，
# 不是「脚本能不能跑通」。`GIT_OPTIONAL_LOCKS=0` 让 git 跳过这类可选的锁；真正要写的 `add`/`commit`
# 照常拿它自己的锁，不受影响。
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
# 🔴 **扫到空集不许报绿**（审查席 2026-10-25 转监督席对照意见：缺依赖默认红，跳过要写明原因）。
# 台账目录本来就该在：不在说明根找错了或项目没初始化，**判红**，不是「什么都对得上」。
for d in ai/tasks ai/bugs ai/decisions; do [ -d "$d" ] || { echo "找不到 $d —— 台账都不在，对账无从谈起（是不是在仓库根下跑的？）"; exit 2; }; done
bad=0
say(){ echo "  ✗  $*"; bad=$((bad+1)); }

# ---- ① 任务字段 ----
REQ="id 标题 提出 派给 状态 优先级 依据 阻塞于 建档 更新"
for f in ai/tasks/T-*.md; do
  [ -e "$f" ] || break
  hdr=$(sed -n '1,/^---$/p' "$f" | sed -n '2,$p')
  miss=""
  for k in $REQ; do grep -qE "^$k:" <<< "$hdr" || miss="$miss $k"; done
  [ -n "$miss" ] && say "$f 文件头缺字段：$miss"
done

# ---- ② 状态双写一致 ----
IDX="ai/tasks/index.md"
if [ -f "$IDX" ]; then
  for f in ai/tasks/T-*.md; do
    [ -e "$f" ] || break
    id=$(grep -m1 '^id:' "$f" | sed 's/^id:[[:space:]]*//;s/[[:space:]]*$//')
    st=$(grep -m1 '^状态:' "$f" | sed 's/^状态:[[:space:]]*//;s/[[:space:]]*#.*//;s/[[:space:]]*$//')
    [ -z "$id" ] && continue
    row=$(grep -m1 -F "[$id]" "$IDX" || true)
    if [ -z "$row" ]; then say "$id 在 $IDX 里没有对应行（改了状态只改一处？）"; continue; fi
    grep -qF "| $st |" <<< "$row" || \
      say "$id 状态双写不一致：文件头＝「$st」，索引那一行不是（$(cut -d'|' -f4 <<< "$row" | tr -d ' ')）"
  done
fi

# ---- ②之二 bug 的状态双写 ----
# 监督席实测抓到的洞：四个 B 文件头全是「已复现」，而 index 里三行还写着「待复现」，
# 而 check-bugs.sh **此刻是绿的**——它只看 B 文件，从不和台账对账。
# 需求方问「还有什么 bug」时读的正是那张表。
BIDX="ai/bugs/index.md"
if [ -f "$BIDX" ]; then
  for f in ai/bugs/B-*.md; do
    [ -e "$f" ] || break
    id=$(grep -m1 '^id:' "$f" | sed 's/^id:[[:space:]]*//;s/[[:space:]]*$//')
    st=$(grep -m1 '^状态:' "$f" | sed 's/^状态:[[:space:]]*//;s/[[:space:]]*#.*//;s/[[:space:]]*$//')
    [ -z "$id" ] && continue
    row=$(grep -m1 -F "$id" "$BIDX" || true)
    if [ -z "$row" ]; then say "$id 在 $BIDX 里没有对应行"; continue; fi
    grep -qF "| $st |" <<< "$row" || \
      say "$id 状态双写不一致：文件头＝「$st」，索引那一行是「$(echo "$row" | cut -d'|' -f6 | tr -d ' ')」"
  done
fi

# ---- ③ 索引与实体 ----
for pair in "ai/specs/index.md:ai/specs" "ai/bugs/index.md:ai/bugs"; do
  idx="${pair%%:*}"; dir="${pair##*:}"
  [ -f "$idx" ] || continue
  while IFS= read -r n; do
    [ -e "$dir/$n" ] || [ -e "$dir/archive/$n" ] || say "$idx 列了 $n，但 $dir/ 和 $dir/archive/ 里都没有"
  done < <(grep -oE '^\|[[:space:]]*~*`[^`]+\.md`' "$idx" | sed 's/.*`\(.*\)`/\1/')
  while IFS= read -r p; do
    n=$(basename "$p"); case "$n" in index.md|README.md) continue;; esac
    grep -qF "\`$n\`" "$idx" || say "$dir/$n 没在 $idx 里登记"
  done < <(find "$dir" -maxdepth 1 -name '*.md')
done

# ---- ③之二 同一个编号不许有第二份文件 ----
# 【为什么要这条】开发席 2026-09-15 实测报来：**一天撞了两次任务重号，这条守门两次都报 OK**。
# 取号点写在 `ai/tasks/index.md`（「下一个可用任务号」），但**没有任何东西在查「这个号是不是已经有人用了」**——
# 两个会话同时取号就会各建一份 `T-0039-…`，而索引只登记其中一份，另一份成了**没人看得见的孤儿**。
# 判的是**要保的那件事**：一个编号只能对应一个实体文件（含 archive/，改名归档后也不许再出现同号）。
for pair in "ai/tasks:T" "ai/bugs:B" "ai/specs:AD"; do
  dir="${pair%%:*}"; pre="${pair##*:}"
  [ -d "$dir" ] || continue
  while IFS= read -r num; do
    [ -n "$num" ] || continue
    hits=$(find "$dir" -maxdepth 2 -name "$num-*.md" | LC_ALL=C sort | paste -sd' ' -)
    say "编号 $num 有两份以上文件（一个号只能有一个实体）：$hits"
  done < <(find "$dir" -maxdepth 2 -name "${pre}-[0-9][0-9][0-9][0-9]-*.md" \
            | sed -E "s#.*/(${pre}-[0-9]{4})-.*#\1#" | LC_ALL=C sort | uniq -d)
done

# ---- ③之四 推「待审」的任务必须有构建对账 ----
# 【为什么要这条】2026-09-22 事故：一个应用的前端 ＋ 三条路由**只在测试机上有、仓库里没有**
#（测试机上跑的那个二进制从仓库根本编不出来），而**七件套全绿、真机验收也全绿**——
# 因为仓库里编得过（缺的文件没人引用）、真机跑的是推上去的那份。
# **逐文件对 sha 只咬得住「已经想起来要写回的那几个」**；能咬住「忘了写回」整类的，是**整棵树重编后对二进制的 sha**。
# 判的是**任务文件里有没有这条账**（有没有写、写了什么），跑不跑得动那条命令是开发席的事。
# 按 §三之三 不追溯：只查生效日之后推到「待审」的任务（闸门用 git 首次入库时间，不用 mtime）。
SINCE_BUILD="${BUILDRECON_SINCE:-2026-09-22}"
if git rev-parse --git-dir >/dev/null 2>&1; then
  # 🔴 **首次入库日期一次查完**（2026-10-29 实测：原来对每条任务各跑一次 `git log --diff-filter=A -- <文件>`，
  # 每次都走完整个历史；一个 65 条任务、几百个提交的项目在挂载盘上这一节超过 120 s，整张巡检超过一次调用的 180 s，
  # 提交脚本现跑巡检就被杀、留锁）。改成整棵 ai/tasks/ 走一遍历史，按文件记最早的那次「新增」——结果与逐个查相同。
  declare -A ADDED=(); d=""
  while IFS= read -r l; do
    case "$l" in 20[0-9][0-9]-*) d="${l:0:10}";; ai/tasks/*) ADDED["$l"]="$d";; esac
  done < <(git -c core.quotepath=false log --diff-filter=A --name-only --format=%cI -- ai/tasks/ 2>/dev/null)
  for f in ai/tasks/T-*.md; do
    [ -f "$f" ] || continue
    st=$(grep -m1 '^状态:' "$f" | sed 's/^状态:[[:space:]]*//;s/[[:space:]].*$//')
    case "$st" in 待审|已过|已过（带遗留）) ;; *) continue;; esac
    a="${ADDED[$f]:-}"
    [ -n "$a" ] && [ "$a" \< "$SINCE_BUILD" ] && continue
    grep -qE 'sha256|构建对账' "$f" || say "$f 推到「$st」却没有**构建对账**（仓库整棵树重编的 sha ＝ 测试机上跑的那份）：ai/rules/workflow.md 的「自测」一节"
  done
fi

# ---- ③之三 记忆卷宗：条目只许增不许减（按整个目录算，卷与卷之间可以挪） ----
# 【为什么要这条】`ai/memory.md` 顶满（80/80）时的解法是**分卷**，不是删行、也不是放宽上限
#（开发席 2026-09-18 报「记忆顶满了」，它自己不肯删别人的行——**那是对的**）。
# 分卷之后卷宗成了唯一的落脚处，所以它和信箱归档同一个判据：**只追加，不删行**。
# 🔴 **按整个目录的条目总数判，不逐份判**（2026-10-05 改）：预算表给席位卷宗留的出口是「满了往 <类型>.md 卷宗里挪」，
# 而原来逐份拿 HEAD 比的写法把这个出口堵死了——挪走一条，原来那一份就红。实测：一席的卷宗顶到 30 行上限，
# 下一条没处写，**规矩写的出口守门不让走**。要保的那件事是「**记忆一条都不许丢**」，不是「这一份文件不许变短」：
# 卷间挪动总数不变，不红；真丢了总数变少，照红，并点名是哪几份变短了。
# 反向断言请指到拷贝上做：MEMARCH_DIR=<拷贝里的相对路径>（要在一个 git 仓库里，基线取 HEAD）。
if git rev-parse --git-dir >/dev/null 2>&1; then
  MA="${MEMARCH_DIR:-ai/memory-archive}"
  rows() { grep -cE '^\|[[:space:]]*[0-9A-Za-z]' || true; }
  cur_total=0; old_total=0; shrunk=""
  for f in "$MA"/*.md; do
    [ -f "$f" ] || continue
    cur_total=$((cur_total + $(rows < "$f")))
  done
  while IFS= read -r f; do
    case "$f" in *.md) ;; *) continue;; esac
    o=$(git show "HEAD:$f" 2>/dev/null | rows)
    old_total=$((old_total + o))
    c=0; [ -f "$f" ] && c=$(rows < "$f")
    [ "$c" -lt "$o" ] && shrunk="$shrunk $(basename "$f")（$o→$c）"
  done < <(git -c core.quotepath=off ls-tree --name-only HEAD "$MA/" 2>/dev/null)
  [ "$cur_total" -lt "$old_total" ] && say "记忆卷宗的条目总数变少了（HEAD $old_total → 现在 $cur_total；变短的：$shrunk）：卷与卷之间可以挪，但一条都不许丢（git show HEAD:<那一份> 找回来）"
fi

# ---- ③之五 写到的编号要真有、取号要往前推 ----
# 【为什么要这条】一个消费项目的同题测试里（监督席 2026-10-31 转告），三个工具都在一轮收尾出错，其中一种是**交接里写了不存在的任务号**，
# 守门只查收件簿清零，看不见。判的是要保的那件事：**开场必读的交接（now.md）、收件簿、任务索引里点到的 T / B / AD，都得有实体**；
# 「下一个可用」号必须大于已有的最大号（否则下一个取号的人会撞号）。写着「下一个可用」的那一行本身不算引用。
REF_FILES="ai/state/now.md product/requirements/inbox.md ai/tasks/index.md ai/bugs/index.md"
# 说明文字里的举例编号不算引用：now.md 整份扫；收件簿与两份索引只看表格数据行，带模板占位 `<…>` 的行跳过。
reflines() { case "$1" in ai/state/now.md) grep -v '下一个可用' "$1";; *) grep -E '^\|' "$1" | grep -v '<' | grep -v '下一个可用';; esac; }
maxof() { sed -E "s/^$1-?0*//" | grep -E '^[0-9]+$' | sort -n | tail -1; }
for pair in "T:ai/tasks" "B:ai/bugs"; do
  pre="${pair%%:*}"; dir="${pair#*:}"; [ -d "$dir" ] || continue
  have="$(find "$dir" -maxdepth 2 -name "${pre}-[0-9][0-9][0-9][0-9]-*.md" | sed -E "s#.*/(${pre}-[0-9]{4})-.*#\1#" | LC_ALL=C sort -u)"
  for rf in $REF_FILES; do
    [ -f "$rf" ] || continue
    miss="$(reflines "$rf" | grep -oE "\b${pre}-[0-9]{4}\b" | grep -v "${pre}-0000" | LC_ALL=C sort -u | LC_ALL=C comm -23 - <(printf '%s\n' "$have"))"
    [ -n "$miss" ] && say "$rf 点到了不存在的 $(printf '%s' "$miss" | paste -sd' ' -)（没有对应的 $dir/<编号>-*.md）"
  done
  mx="$(printf '%s\n' "$have" | maxof "$pre")"
  nx="$(grep -h '下一个可用' "$dir/index.md" 2>/dev/null | grep -oE "${pre}-[0-9]{4}" | head -1 | maxof "$pre")"
  [ -n "$mx" ] && [ -n "$nx" ] && [ "$nx" -le "$mx" ] && say "$dir/index.md「下一个可用」是 ${pre}-$(printf '%04d' "$nx")，可已有 ${pre}-$(printf '%04d' "$mx")——取号没往前推，下一个人会撞号"
done
if [ -d ai/decisions ]; then
  admax="$(grep -ohE '^\|[[:space:]]*(\*\*)?AD[0-9]+' ai/decisions/AD[0-9]*-[0-9]*.md 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)"
  adnx="$(grep -h '下一个可用' ai/decisions/index.md 2>/dev/null | grep -oE 'AD[0-9]+' | head -1 | grep -oE '[0-9]+')"
  if [ -n "$admax" ]; then
    for rf in $REF_FILES; do
      [ -f "$rf" ] || continue
      over="$(reflines "$rf" | grep -oE '\bAD[0-9]{1,4}\b' | grep -oE '[0-9]+' | sort -un | awk -v m="$admax" '$1>m {printf "AD%s ", $1}')"
      [ -n "$over" ] && say "$rf 点到了还没记的决策 ${over}（台账里最大是 AD$admax）"
    done
    [ -n "$adnx" ] && [ "$adnx" -le "$admax" ] && say "ai/decisions/index.md「下一个可用」是 AD$adnx，可已有 AD$admax——取号没往前推"
  fi
fi

# ---- ④ ai/ 根下的散件 ----
while IFS= read -r f; do
  case "$(basename "$f")" in
    index.md|memory.md|check-links.sh|.linkcheck-ignore|glossary.md|frame-manifest.txt|frame-repo.conf|FRAME-VERSION) ;;
    *) say "ai/ 根下多了一个散件：$f（ai/rules/layout.md §二：ai/ 下只放子目录 + 那几份）";;
  esac
done < <(find ai -maxdepth 1 -type f)

if [ "$bad" -gt 0 ]; then echo; echo "LEDGER-FAIL（$bad 处对不上）"; exit 1; fi
echo "LEDGER-OK（$(ls ai/tasks/T-*.md 2>/dev/null | wc -l) 条任务、$(ls ai/bugs/B-*.md 2>/dev/null | wc -l) 条 bug：字段齐、双写一致、索引与实体对得上）"
