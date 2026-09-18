#!/usr/bin/env bash
# check-budget: 行数预算有没有被超，以及**开场必读**到底多少行。
# 用法：bash ops/verify/check-budget.sh
# 退出码 0 = 都在预算内；1 = 有超的；2 = 结构不对。
#
# 【为什么要这条】监督席体检时指出：六条守门当时全绿，而同一时刻
# **至少 5 条写进规范的硬约束正在被违反**，其中包括 `CLAUDE.md` 自己 121 行 / 预算 80 行。
# 原因很简单：**预算写在文档里，没有任何东西在看它**。
# 更糟的是它还发现「职责多了就把上限从 150 改成 300」——**尺子会被悄悄放大**。
#
# 【这条守门怎么让尺子不能悄悄变】
#   · 预算的唯一出处是 `ai/rules/layout.md` 的预算表，本脚本**从那张表读**，不自己抄一份；
#   · 想放宽，就得**改那张表**——那是一次看得见的规范修改，按规矩要进维护记录；
#   · **开场必读总量**单独设一个硬顶：它才是预算真正要管的那笔成本。
#
# 【判的是要保的那件事】判的是**真实行数**（`wc -l`），不是「文档里声称多少行」。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
L="ai/rules/layout.md"
[ -f "$L" ] || { echo "找不到 $L（预算表在那儿）"; exit 2; }

# 开场必读总量硬顶：四席里最贵的那一席不许超过它。
# **2026-09-15 从 600 放宽到 660**，理由记在 ai/rules/maintenance-log.md：
# 开场必读从四份变成五份（新增 ai/memory.md 项目记忆，80 行）。
# 同一轮已经从角色手册与 workflow 往「按需读」的文件挪走约 180 行，
# **这 60 行不是靠放宽尺子省出来的，是真的加了一份必读文件**。
OPENING_CAP=660

bad=0

# ---- ① 逐份比预算表 ----
# 表行形如：| `path` | 80 行 | 超了怎么办 |
while IFS= read -r line; do
  f=$(sed -n 's/^|[[:space:]]*`\([^`]*\)`.*/\1/p' <<< "$line")
  n=$(sed -n 's/^|[^|]*|[^0-9]*\([0-9]\+\)[[:space:]]*行.*/\1/p' <<< "$line")
  [ -z "$f" ] || [ -z "$n" ] && continue
  # 通配行：`T-*.md` 这类**展开来逐个查**；占位符（<名>、####）跳过。
  # 【为什么改】第一版无条件 `continue`，注释写着「单独处理」而**根本没有单独处理**——
  # 于是 `ai/roles/*.md` 从来没被查过，`maintainer.md` 213 行 / 上限 150 而守门一直是绿的。
  # **假绿比没有守门更危险**，这条是自己踩出来的（项目记忆类型 4）。
  case "$f" in
    *'<'*|*'####'*) continue;;
    *'*'*)
      for g in $f; do
        [ -e "$g" ] || continue
        a=$(wc -l < "$g")
        if [ "$a" -gt "$n" ]; then
          echo "  ✗  $g  实际 $a 行 / 预算 $n 行（超 $((a-n))）"; bad=$((bad+1))
        fi
      done
      continue;;
  esac
  [ -e "$f" ] || continue
  a=$(wc -l < "$f")
  if [ "$a" -gt "$n" ]; then
    echo "  ✗  $f  实际 $a 行 / 预算 $n 行（超 $((a-n))）"
    bad=$((bad+1))
  fi
done < <(grep -E '^\|[[:space:]]*`' "$L")

# ---- ② 开场必读总量（这才是预算真正要管的成本）----
common=$(( $(wc -l < CLAUDE.md) + $(wc -l < ai/rules/laws.md) + $(wc -l < ai/state/now.md) + $(wc -l < ai/tasks/index.md) + $(wc -l < ai/memory.md) ))
worst=0; worst_role=""
for r in developer reviewer supervisor; do
  f="ai/roles/$r.md"; [ -e "$f" ] || continue
  t=$(( common + $(wc -l < "$f") ))
  # 开场第一件事是查信：算上它自己那个目录下的三份投递口（每份 ≤15 行）
  for m in ai/mail/to-$r/from-*.md; do [ -e "$m" ] && t=$(( t + $(wc -l < "$m") )); done
  # 监督席按规矩**不读任务队列**（ai/roles/supervisor.md §一 的 🔴），所以不算它
  [ "$r" = supervisor ] && t=$(( t - $(wc -l < ai/tasks/index.md) ))
  printf '  开场必读 · %-10s %4d 行\n' "$r" "$t"
  [ "$t" -gt "$worst" ] && { worst=$t; worst_role=$r; }
done
echo "  （＝ CLAUDE.md + laws.md + memory.md + now.md + tasks/index.md + 该席手册 + mail/to-该席/ 三份）"
if [ "$worst" -gt "$OPENING_CAP" ]; then
  echo "  ✗  最贵的一席（$worst_role）$worst 行 > 硬顶 $OPENING_CAP 行"
  echo "     要么把内容挪进「按需读」的文件，要么改硬顶——**改硬顶要进维护记录**。"
  bad=$((bad+1))
fi

if [ "$bad" -gt 0 ]; then
  echo; echo "BUDGET-FAIL（$bad 处超预算）"
  echo "  预算的唯一出处是 $L 的预算表。**放宽上限＝改规范**，要在 ai/rules/maintenance-log.md 记一条。"
  exit 1
fi
echo "BUDGET-OK（逐份都在预算内；开场必读最贵一席 $worst 行 / 硬顶 $OPENING_CAP）"
