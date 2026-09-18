#!/usr/bin/env bash
# check-inbox: 收件簿里还有没有没处置的行。
# 用法：在仓库根执行   bash ops/verify/check-inbox.sh
# 退出码 0 = 都有去处；1 = 还有 待处理（审查者一轮结束前不许有）。
#
# 为什么要这条：需求方只跟审查者说话，他说的每一件事都得有回音。
# 靠人记「他刚才还提了个啥」是不可靠的——一轮里插三次话，第二次那件就容易蒸发。
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/CLAUDE.md" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/CLAUDE.md" ] || { echo "找不到仓库根"; exit 2; }
INBOX="$ROOT/product/requirements/inbox.md"
[ -f "$INBOX" ] || { echo "找不到收件簿 $INBOX"; exit 2; }

# 表格行：以 | 开头、第二格是数字的那些；跳过模板示例行（含 <）
pending=$(grep -E '^\|[[:space:]]*[0-9]+[[:space:]]*\|' "$INBOX" | grep -v '<' | grep -E '\|[[:space:]]*(待处理)[[:space:]]*\|?[[:space:]]*$')
waiting=$(grep -E '^\|[[:space:]]*[0-9]+[[:space:]]*\|' "$INBOX" | grep -v '<' | grep -E '\|[[:space:]]*(待确认)[[:space:]]*\|?[[:space:]]*$')

[ -n "$waiting" ] && { echo "== 等需求方拍板（不算未处置，但别忘了催）=="; printf '%s\n' "$waiting" | cut -c1-120; echo; }

if [ -n "$pending" ]; then
  echo "== ❌ 还没定去处的（一轮结束前必须清零）=="
  printf '%s\n' "$pending" | cut -c1-120
  echo
  echo "INBOX-FAIL：每一行都要有处置——转任务 / 转规格 / 已答复 / 不做（写明原因）。"
  exit 1
fi
echo "INBOX-OK（收件簿里没有待处理的行）"
