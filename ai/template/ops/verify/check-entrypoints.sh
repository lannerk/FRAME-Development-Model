#!/usr/bin/env bash
# check-entrypoints: 别的 AI 平台的入口文件有没有变成第二份真相。
# 用法：bash ops/verify/check-entrypoints.sh
# 退出码 0 = 都还是指针；1 = 有入口文件长胖了或指错了；2 = 结构不对。
#
# 为什么要这条：不同平台自动加载不同的入口文件（CLAUDE.md / AGENTS.md / GEMINI.md …）。
# 最省事的做法是把 CLAUDE.md 抄一份——而两份入口文档一旦并存就会**慢慢分叉，且没有任何症状**：
# 有人只改了其中一份，另一份照样被加载，直到某个会话按过时的规矩干完活才发现。
# 所以规矩是：**真入口只有 CLAUDE.md，其余一律只写一句指路**。这条守门就判这一件事。
#
# 它判的是「要保的那件事」本身：**别名文件里有没有塞进规矩**——
# 判据是「够短」+「确实指向 CLAUDE.md」，不是「有没有出现某个关键词」。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2

MAX_LINES=25          # 一句指路 + 一段解释，够用了；超了就是开始抄内容
bad=0

[ -f CLAUDE.md ] || { echo "  ✗  找不到 CLAUDE.md —— 它是真入口，而且守门脚本靠它找仓库根。"; exit 1; }

# 别名入口：各平台会自动加载的那些
for f in AGENTS.md AGENT.md GEMINI.md .github/copilot-instructions.md .cursorrules; do
  [ -f "$f" ] || continue
  n=$(wc -l < "$f")
  if [ "$n" -gt "$MAX_LINES" ]; then
    echo "  ✗  $f 有 $n 行（上限 $MAX_LINES）—— 它应该只是一句指路，不是第二份规矩。"
    echo "     两份入口会分叉，而且没有症状。内容留在 CLAUDE.md 一处。"
    bad=$((bad+1))
  fi
  if ! grep -q 'CLAUDE\.md' "$f"; then
    echo "  ✗  $f 里没有指向 CLAUDE.md —— 那它到底把人送去哪？"
    bad=$((bad+1))
  fi
done

if [ "$bad" -gt 0 ]; then
  echo
  echo "ENTRYPOINTS-FAIL（$bad 处）"
  exit 1
fi
echo "ENTRYPOINTS-OK（真入口只有 CLAUDE.md，别名都还是指针）"
