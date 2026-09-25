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
#（测试机上那个 inosd 从仓库根本编不出来），而**七件套全绿、真机验收也全绿**——
# 因为仓库里编得过（缺的文件没人引用）、真机跑的是推上去的那份。
# **逐文件对 sha 只咬得住「已经想起来要写回的那几个」**；能咬住「忘了写回」整类的，是**整棵树重编后对二进制的 sha**。
# 判的是**任务文件里有没有这条账**（有没有写、写了什么），跑不跑得动那条命令是开发席的事。
# 按 §三之三 不追溯：只查生效日之后推到「待审」的任务（闸门用 git 首次入库时间，不用 mtime）。
SINCE_BUILD="${BUILDRECON_SINCE:-2026-09-22}"
if git rev-parse --git-dir >/dev/null 2>&1; then
  for f in ai/tasks/T-*.md; do
    [ -f "$f" ] || continue
    st=$(grep -m1 '^状态:' "$f" | sed 's/^状态:[[:space:]]*//;s/[[:space:]].*$//')
    case "$st" in 待审|已过|已过（带遗留）) ;; *) continue;; esac
    a=$(git log --diff-filter=A --format=%cI -- "$f" 2>/dev/null | tail -1 | cut -c1-10)
    [ -n "$a" ] && [ "$a" \< "$SINCE_BUILD" ] && continue
    grep -qE 'sha256|构建对账' "$f" || say "$f 推到「$st」却没有**构建对账**（仓库整棵树重编的 sha ＝ 测试机上跑的那份）：ai/rules/workflow.md 的「自测」一节"
  done
fi

# ---- ③之三 记忆卷宗只许增不许减 ----
# 【为什么要这条】`ai/memory.md` 顶满（80/80）时的解法是**分卷**，不是删行、也不是放宽上限
#（开发席 2026-09-18 报「记忆顶满了」，它自己不肯删别人的行——**那是对的**）。
# 分卷之后卷宗成了唯一的落脚处，所以它和信箱归档同一个判据：**只追加，不删行**。
if git rev-parse --git-dir >/dev/null 2>&1; then
  for f in ai/memory-archive/*.md; do
    [ -f "$f" ] || continue
    cur=$(grep -cE '^\|[[:space:]]*[0-9A-Za-z]' "$f" || true)
    if git cat-file -e "HEAD:$f" 2>/dev/null; then
      old=$(git show "HEAD:$f" 2>/dev/null | grep -cE '^\|[[:space:]]*[0-9A-Za-z]' || true)
      [ "$cur" -lt "$old" ] && say "$f 条目变少了（HEAD $old → 现在 $cur）：记忆卷宗只许增不许减（git show HEAD:$f 找回来）"
    fi
  done
fi

# ---- ④ ai/ 根下的散件 ----
while IFS= read -r f; do
  case "$(basename "$f")" in
    index.md|memory.md|check-links.sh|.linkcheck-ignore|glossary.md|frame-manifest.txt|frame-repo.conf|FRAME-VERSION) ;;
    *) say "ai/ 根下多了一个散件：$f（ai/rules/layout.md §二：ai/ 下只放子目录 + 那几份）";;
  esac
done < <(find ai -maxdepth 1 -type f)

if [ "$bad" -gt 0 ]; then echo; echo "LEDGER-FAIL（$bad 处对不上）"; exit 1; fi
echo "LEDGER-OK（字段齐、双写一致、索引与实体对得上）"
