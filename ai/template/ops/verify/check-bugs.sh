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
# 【BUGS_DIR 旋钮】反向断言要在**拷贝**上造错，不许在活 bug 文件上造（项目记忆第 11、13 条：
# 上一次在真信箱上造错，删掉了两封真信）。默认仍是 ai/bugs。
D="${BUGS_DIR:-ai/bugs}"
# 🔴 **挂起（⏸）：把「等外部条件」和「没人复测」分开**（审查席 2026-09-23 提，实测发作过）。
# 旧判据是「只要有 `修复待复测` 就报红」。它保的那件事没错——**修好的东西不许没人复测就躺着**——
# 但真机类 bug 等的是「装机盘真装一次」「需求方插第二根网线」这种**审查席无权解决的外部条件**，
# 于是这条红永远在，而**永远在的红等于没有红**：久了谁都不看它，连真的断口也一起看不见了。
# 新判据：写全 `阻塞于:` 与 `解除人:` 两行的 `修复待复测` **不计断口，但单独列出来**；
# 🔴 **挂起不是归档**——超过 $BLOCKED_MAX 天没动照样报红（防止它变成新的垃圾桶，这是审查席自己提的防线）。
# 「没动」判的是 **git 最近一次提交时间**（§三之三 同一条判据：mtime 一次 clone 就全变了）。
BLOCKED_MAX="${BUG_BLOCKED_MAX_DAYS:-21}"
days_since() {  # 这个文件最近一次 git 提交到今天几天；没进过 git 就算 0（新建的不算陈）
  local iso ts now
  iso=$(git -C "$ROOT" log -1 --format=%cI -- "$1" 2>/dev/null)
  [ -n "$iso" ] || { echo 0; return; }
  ts=$(date -d "$iso" +%s 2>/dev/null) || { echo 0; return; }
  now=$(date +%s); echo $(( (now - ts) / 86400 ))
}
fld() {  # fld <文件> <字段名>：读表头一行，— 和 无 都算空
  local v; v=$(grep -m1 "^$2:" "$1" | sed "s/^$2:[[:space:]]*//; s/[[:space:]]*#.*//; s/[[:space:]]*$//")
  case "$v" in —|-|无|N/A) v="";; esac; printf '%s' "$v"
}
held=0
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
  blk="$(fld "$f" 阻塞于)"; who="$(fld "$f" 解除人)"
  if [ "$st" = "修复待复测" ]; then
    if [ -n "$blk" ] && [ -n "$who" ]; then
      held=$((held+1)); d="$(days_since "$f")"
      if [ "$d" -gt "$BLOCKED_MAX" ]; then
        echo "  ✗  $f —— 挂起 $d 天没动（上限 $BLOCKED_MAX 天）：等「$blk」，解除人 $who。"
        echo "     挂起不是归档：条件到了就复测，没到就去催解除人，催不动就改判它不修并写清理由。"
        bad=$((bad+1))
      else
        echo "  ⏸  $f —— 挂起 $d 天：等「$blk」（解除人：$who）—— 等的是外部条件，不计断口。"
      fi
    elif [ -n "$blk" ] || [ -n "$who" ]; then
      echo "  ✗  $f —— 挂起要两行写全：阻塞于 = 等什么外部条件 · 解除人 = 谁能把它变出来。"
      echo "     只写一半的挂起是无主的，没人知道该去催谁——那正是它会烂在那儿的原因。"
      bad=$((bad+1))
    else
      echo "  ⟳  $f —— 状态「修复待复测」：开发说修好了，**审查席还没复测**。"
      echo "     复测不挂在口令上，本轮就要做（ai/bugs/README.md）。"
      echo "     真的在等外部条件（真机、硬件、需求方的动作），就写上「阻塞于:」与「解除人:」两行。"
      bad=$((bad+1))
    fi
  elif [ -n "$blk" ]; then
    echo "  ✗  $f（状态 $st）—— 只有「修复待复测」能挂起。"
    echo "     别的状态写「阻塞于:」等于给自己开豁免：待修就是还没修，待复现就是还没复现。"
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
  echo "BUGS-FAIL（$bad 处断口；⏸ 另有 $held 条挂起等外部条件，不计在内）"
  exit 1
fi
echo "BUGS-OK（$(echo "$files" | wc -l) 条 bug，闭环没断；⏸ 挂起 $held 条等外部条件）"
