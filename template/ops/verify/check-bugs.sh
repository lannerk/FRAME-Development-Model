#!/usr/bin/env bash
# check-bugs: bug 闭环有没有断在中间。
# 用法：bash ops/verify/check-bugs.sh
# 退出码 0 = 闭环没断；1 = 有断口（列出来）；2 = 结构不对。
#
# 它判的是「要保的那件事」本身，不是文本影子：
#   ① 一条能转给开发的 bug，必须真的写得出复现步骤 —— 判据是**「步骤」下面有编号行**，
#      不是「文件里出现过『步骤』两个字」。
#   ② 修完没复测的 bug 不许留过夜 —— 状态 `修复待复测` 存在就报红。
#   ③ 开发不许自己关 bug —— `已关闭` 的必须有「复测」一节写了东西。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
D="ai/bugs"
[ -d "$D" ] || { echo "找不到 $D"; exit 2; }

bad=0
# 「定位三小节 / 绕法 / 前置断言」这三条是 2026-09-15 新加的规矩。
# 按 ai/rules/workflow.md §三之三「不追溯」：**只对这一天之后建档的 bug 生效**，
# 之前的旧件只提醒、不计红——开发不可能按一份还不存在的模板写东西。
SINCE="${BUGRULES_SINCE:-2026-09-16}"
newer() {   # $1=文件；建档日 >= SINCE 返回 0
  local d; d=$(grep -m1 '^发现:' "$1" | sed 's/^发现:[[:space:]]*//;s/[[:space:]]*$//')
  [ -z "$d" ] && return 0
  [ "$d" \> "$SINCE" ] || [ "$d" = "$SINCE" ]
}
note(){ echo "  ·  $* （旧件，按 §三之三 不追溯）"; }

files=$(find "$D" -maxdepth 2 -name 'B-*.md' | LC_ALL=C sort)

if [ -z "$files" ]; then
  echo "BUGS-OK（还没有 bug 文件——台账是空的，不是坏的）"
  exit 0
fi

for f in $files; do
  st=$(grep -m1 '^状态:' "$f" | sed 's/^状态:[[:space:]]*//; s/[[:space:]]*#.*//; s/[[:space:]]*$//')
  case "$st" in
    已复现|待修|修复待复测|已关闭)
      # ① 复现步骤必须真的有编号步骤行
      steps=$(sed -n '/^-[[:space:]]*\*\*步骤\*\*/,/^-[[:space:]]*\*\*现象\*\*/p' "$f" \
              | grep -cE '(^|[[:space:]])[0-9]+\.[[:space:]]*[^[:space:]]')
      if [ "$steps" -lt 1 ]; then
        echo "  ✗  $f（状态 $st）—— 复现「步骤」里没有一条编号步骤。"
        echo "     开发拿不到还原条件，修的会是另一个问题。"
        bad=$((bad+1))
      fi
      ;;
  esac
  if [ "$st" = "修复待复测" ]; then
    echo "  ⟳  $f —— 状态「修复待复测」：开发说修好了，**审查席还没复测**。"
    echo "     复测不挂在口令上，本轮就要做（ai/rules/workflow.md §三之二）。"
    bad=$((bad+1))
  fi
  # ④ 「定位」节三小标题（状态 ≥ 已复现 才要求）——监督席体检提的
  case "$st" in
    已复现|待修|修复待复测|已关闭)
      for h in "能不能本地复现" "排除树" "结论或当前假设"; do
        grep -qE "^###[[:space:]]*$h" "$f" || {
          if newer "$f"; then
            echo "  ✗  $f（状态 $st）—— 「定位」节缺小标题「$h」（ai/bugs/README.md）"
            bad=$((bad+1))
          else note "$f 缺「$h」"; fi; }
      done
      ;;
  esac
  # ⑤ 绕法只能待在「临时缓解」里
  if grep -qE '绕过|绕开|换个窗口|无痕|临时用着' "$f"; then
    grep -qE '^##[[:space:]]*临时缓解' "$f" || {
      if newer "$f"; then
        echo "  ✗  $f —— 写了绕法，却没有「## 临时缓解」小节。"
        echo "     绕法回答的是「现在怎么先用着」，不回答「为什么会这样」——它不是交付。"
        bad=$((bad+1))
      else note "$f 绕法没进「临时缓解」"; fi; }
  fi
  # ⑥ 「没复现出来」只有在前置断言全绿时才算结论
  if grep -qE '未复现|没复现出来|复现不了' "$f"; then
    grep -q '前置断言' "$f" || {
      if newer "$f"; then
        echo "  ✗  $f —— 写了「没复现出来」，却没有「前置断言」。"
        echo "     没有前置断言的「没复现」，只是「我的台子没跑起来」。"
        bad=$((bad+1))
      else note "$f 「没复现」缺前置断言"; fi; }
  fi
  if [ "$st" = "已关闭" ]; then
    body=$(sed -n '/^##[[:space:]]*复测/,$p' "$f" | tail -n +2 | grep -cE '[^[:space:]]')
    if [ "$body" -lt 1 ]; then
      echo "  ✗  $f —— 标了「已关闭」，但「复测」一节是空的。"
      echo "     关闭权在审查席，且必须写清怎么验的。"
      bad=$((bad+1))
    fi
  fi
done

if [ "$bad" -gt 0 ]; then
  echo
  echo "BUGS-FAIL（$bad 处断口）"
  exit 1
fi
echo "BUGS-OK（$(echo "$files" | wc -l) 条 bug，闭环没断）"
