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

# ---- ④ ai/ 根下的散件 ----
while IFS= read -r f; do
  case "$(basename "$f")" in
    index.md|memory.md|check-links.sh|.linkcheck-ignore|glossary.md|frame-manifest.txt) ;;
    *) say "ai/ 根下多了一个散件：$f（ai/rules/layout.md §二：ai/ 下只放子目录 + 那几份）";;
  esac
done < <(find ai -maxdepth 1 -type f)

if [ "$bad" -gt 0 ]; then echo; echo "LEDGER-FAIL（$bad 处对不上）"; exit 1; fi
echo "LEDGER-OK（字段齐、双写一致、索引与实体对得上）"
