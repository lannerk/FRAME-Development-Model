#!/usr/bin/env bash
# check-randd: whether the R&D line (ai/RandD/) still has its structure and its indexes.
# Usage: bash ops/verify/check-randd.sh
#        RANDD_DIR=/tmp/rdtest bash ops/verify/check-randd.sh   <- run reverse assertions against a COPY
# Exit codes: 0 = clean, or not applicable; 1 = something is wrong; 2 = the structure is wrong.
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
[ -d "$D" ] || { echo "RANDD-SKIP (no $D; this project has not opened an R&D line)"; exit 0; }

bad=0; topics=0
IDX="$D/index.md"
[ -f "$IDX" ] || { echo "  x  missing $IDX -- the topic list is the only way in to any topic"; bad=$((bad+1)); }
[ -f "$D/README.md" ] || { echo "  x  missing $D/README.md -- the directory and numbering rules have no source"; bad=$((bad+1)); }

# 线级记忆：格式同 ai/memory.md，上限 80 行（预算表 ai/rules/layout.md §三 是唯一出处，这里只查存在与行数）
if [ -f "$D/memory.md" ]; then
  n=$(wc -l < "$D/memory.md")
  [ "$n" -gt 80 ] && { echo "  x  $D/memory.md  $n lines / cap 80 -- move whole blocks into the topic notes/ and leave one pointer line"; bad=$((bad+1)); }
fi

for t in "$D"/*/; do
  [ -d "$t" ] || continue
  b=$(basename "$t")
  case "$b" in archive|drafts) continue;; esac
  topics=$((topics+1))

  # ① 骨架齐全
  # 🔴 **Match on the `00-` `01-` `02-` prefix, not on the file name**: the second half of the name follows
  # the project's language (00-status.md here, 00-现状.md in a Chinese project) -- **the prefix is the stable half**.
  # What must hold is that those three things exist, not that they are called something in particular.
  for f in README.md decisions.md tasks/index.md; do
    [ -f "$t$f" ] || { echo "  x  $t is missing $f -- the topic skeleton is incomplete (half a skeleton is worse than none)"; bad=$((bad+1)); }
  done
  for pre in 00 01 02; do
    ls "$t$pre"-*.md >/dev/null 2>&1 || { echo "  x  $t is missing $pre-*.md (status / open questions / ideas; the name follows your language, the prefix does not)"; bad=$((bad+1)); }
  done
  # ② 四个归档目录各要有 INDEX.md（目录在就得有索引）
  for d in log lab runs notes; do
    [ -d "$t$d" ] || continue
    [ -f "$t$d/INDEX.md" ] || { echo "  x  $t$d/ has no INDEX.md -- an archive without an index does not exist three months later"; bad=$((bad+1)); }
  done
  # ③ index.md 里要有这个话题的一行
  if [ -f "$IDX" ]; then
    num=${b%%-*}
    grep -qF -- "$b" "$IDX" || grep -qE "^\| *\`?$num\`? *\|" "$IDX" \
      || { echo "  x  $b is not listed in $IDX -- a topic nobody can find is a topic that is not there"; bad=$((bad+1)); }
  fi
  # ④ 活文件行数（死的那几份不限）
  for pair in "00:200" "01:100"; do
    pre="${pair%%:*}"; cap="${pair##*:}"
    for f in "$t$pre"-*.md; do
      [ -f "$f" ] || continue
      n=$(wc -l < "$f")
      [ "$n" -gt "$cap" ] && { echo "  x  $f  $n lines / cap $cap (only the live files have a cap; log/ lab/ runs/ notes/ and the ideas book do not)"; bad=$((bad+1)); }
    done
  done
  if [ -f "$t"README.md ]; then
    n=$(wc -l < "$t"README.md)
    [ "$n" -gt 50 ] && { echo "  x  $t""README.md  $n lines / cap 50 (the topic card holds what/criteria/status only; the process lives in log/)"; bad=$((bad+1)); }
  fi
  # ⑤ 标了「已毕业」就必须有九条全绿的自查
  if [ -f "$IDX" ] && grep -F -- "$b" "$IDX" | grep -q "已毕业"; then
    sc=$(ls "$t"graduation/04-*.md 2>/dev/null | head -1)
    if [ -z "$sc" ]; then
      echo "  x  $b is marked graduated in $IDX, but graduation/ has no 04-* self-check -- nine criteria unchecked is not graduation"; bad=$((bad+1))
    else
      green=$(grep -cE '✅|全绿|通过' "$sc" || true)
      [ "$green" -ge 9 ] || { echo "  x  $sc shows only $green green items / 9 required -- no graduating first and filling the gaps later"; bad=$((bad+1)); }
    fi
  fi
done

if [ "$bad" -gt 0 ]; then
  echo "RANDD-FAIL ($bad)"
  echo "  The rules are in $D/README.md: one directory per topic; an INDEX.md in each archive dir; caps on the live files; nine green criteria before graduation."
  exit 1
fi
echo "RANDD-OK ($topics topics: skeletons complete, indexes present, live files within their caps, graduations self-checked)"
