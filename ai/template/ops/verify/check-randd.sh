#!/usr/bin/env bash
# check-randd: R&D 线（ai/RandD/）的结构与索引有没有烂掉。
# 用法：bash ops/verify/check-randd.sh
#       RANDD_DIR=/tmp/rdtest bash ops/verify/check-randd.sh   ← 反向断言请指到拷贝上做
# 退出码 0 = 干净或不适用；1 = 有问题；2 = 结构不对。
#
# 【为什么要这条】R&D 线的北极星是「毕业时能把整个过程重建出来」（ai/RandD/README.md）。
# 能不能重建，靠的不是有没有写，而是**有没有索引、活文件有没有失控、毕业有没有真自查过**。
# 这三样都能机器判，**靠人记就等于没有**——这一条是这套方法自己的判据。
#
# 【判的是要保的那件事】
#   ① 一个话题目录要么齐全，要么它不是话题目录——**半个骨架比没有更坏**（下一个人以为它在那儿）；
#   ② `log/ lab/ runs/ notes/` 各要有 `INDEX.md`：**没有索引的归档，三个月后等于不存在**；
#   ③ 话题必须在 `index.md` 里有一行：**找不到的话题等于没有**；
#   ④ 活文件（00-现状 200 / 01-未决问题 100 / 话题卡 50）与线级记忆（80）不许超——
#      死的那几个（log/lab/runs/notes/想法册）**一律不限**，它们靠「平时不读」控成本，**不靠删内容**；
#   ⑤ 🔴 状态标成「已毕业」的，`graduation/04-判据自查.md` 必须存在且**九条全绿**——
#      不判这条，「先毕业、缺的以后补」一定会发生，而那笔账会在开发中期以十倍代价爆出来。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
D="${RANDD_DIR:-ai/RandD}"

# 【新项目怎么办】没有这条线就跳过，不是报错——R&D 线开不开由需求方定。
[ -d "$D" ] || { echo "RANDD-SKIP（没有 $D，这个项目没开 R&D 线）"; exit 0; }

bad=0; topics=0
IDX="$D/index.md"
[ -f "$IDX" ] || { echo "  x  缺 $IDX —— 话题一览是找到任何话题的唯一入口"; bad=$((bad+1)); }
[ -f "$D/README.md" ] || { echo "  x  缺 $D/README.md —— 目录与编号规矩没有出处"; bad=$((bad+1)); }

# 线级记忆：格式同 ai/memory.md，上限 80 行（预算表 ai/rules/layout.md §三 是唯一出处，这里只查存在与行数）
if [ -f "$D/memory.md" ]; then
  n=$(wc -l < "$D/memory.md")
  [ "$n" -gt 80 ] && { echo "  x  $D/memory.md  $n 行 / 上限 80 —— 满了把成段的挪进对应话题的 notes/，只留一行指路"; bad=$((bad+1)); }
fi

for t in "$D"/*/; do
  [ -d "$t" ] || continue
  b=$(basename "$t")
  case "$b" in archive|drafts) continue;; esac
  topics=$((topics+1))

  # ① 骨架齐全
  # 🔴 **按 `00-` `01-` `02-` 前缀认，不按文件名认**：名字后半截跟着项目语言走
  # （模板里是 00-status.md，中文项目里可能叫 00-现状.md），**前缀才是稳定的那一半**。
  # 判的是「有没有这三样东西」，不是「有没有叫这个名字」。
  for f in README.md decisions.md tasks/index.md; do
    [ -f "$t$f" ] || { echo "  x  $t 缺 $f —— 话题骨架不全（半个骨架比没有更坏）"; bad=$((bad+1)); }
  done
  for pre in 00 01 02; do
    ls "$t$pre"-*.md >/dev/null 2>&1 || { echo "  x  $t 缺 $pre-*.md（现状/未决问题/想法册这三份，名字按项目语言，前缀固定）"; bad=$((bad+1)); }
  done
  # ② 四个归档目录各要有 INDEX.md（目录在就得有索引）
  for d in log lab runs notes; do
    [ -d "$t$d" ] || continue
    [ -f "$t$d/INDEX.md" ] || { echo "  x  $t$d/ 没有 INDEX.md —— 没有索引的归档，三个月后等于不存在"; bad=$((bad+1)); }
  done
  # ③ index.md 里要有这个话题的一行
  if [ -f "$IDX" ]; then
    num=${b%%-*}
    grep -qF -- "$b" "$IDX" || grep -qE "^\| *\`?$num\`? *\|" "$IDX" \
      || { echo "  x  $b 没登记进 $IDX —— 找不到的话题等于没有"; bad=$((bad+1)); }
  fi
  # ④ 活文件行数（死的那几份不限）
  for pair in "00:200" "01:100"; do
    pre="${pair%%:*}"; cap="${pair##*:}"
    for f in "$t$pre"-*.md; do
      [ -f "$f" ] || continue
      n=$(wc -l < "$f")
      [ "$n" -gt "$cap" ] && { echo "  x  $f  $n 行 / 上限 $cap（活的那几份才有上限；log/ lab/ runs/ notes/ 想法册不限）"; bad=$((bad+1)); }
    done
  done
  if [ -f "$t"README.md ]; then
    n=$(wc -l < "$t"README.md)
    [ "$n" -gt 50 ] && { echo "  x  $t""README.md  $n 行 / 上限 50（话题卡只写「解决什么·判据·状态」，过程在 log/）"; bad=$((bad+1)); }
  fi
  # ⑤ 标了「已毕业」就必须有九条全绿的自查
  if [ -f "$IDX" ] && grep -F -- "$b" "$IDX" | grep -q "已毕业"; then
    sc=$(ls "$t"graduation/04-*.md 2>/dev/null | head -1)
    if [ -z "$sc" ]; then
      echo "  x  $b 在 $IDX 里标了「已毕业」，但 graduation/ 下没有 04-*（判据自查）—— 九条判据没自查过就不算毕业"; bad=$((bad+1))
    else
      green=$(grep -cE '✅|全绿|通过' "$sc" || true)
      [ "$green" -ge 9 ] || { echo "  x  $sc 里够绿的条目只有 $green 条 / 需要 9 条 —— 不许「先毕业，缺的以后补」"; bad=$((bad+1)); }
    fi
  fi
done

if [ "$bad" -gt 0 ]; then
  echo "RANDD-FAIL（$bad 处）"
  echo "  规矩在 $D/README.md：一话题一目录 · 四个归档目录各有 INDEX.md · 活的那三份有上限 · 九条判据全绿才算毕业。"
  exit 1
fi
echo "RANDD-OK（$topics 个话题：骨架齐、索引在、活文件没超、毕业的都自查过）"
