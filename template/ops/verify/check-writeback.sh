#!/usr/bin/env bash
# check-writeback: 真机改完的东西，有没有真的回到仓库里。
# 用法：bash ops/verify/check-writeback.sh
# 退出码 0 = 没有挂着的回写；1 = 有（列出来）。
#
# 【为什么要这条】开发席在真机上改完，必须同轮写回仓库——**仓库才是源，真机是易变现网**。
# 但 Windows 侧经常拒写（文件被编辑器或 Defender 占着），于是就出现了
# 「改了真机、没写回仓库」的静默分叉：下一段有人从仓库出发，把真机上的改动覆盖回去，
# **而且两边都不会报错**。
#
# 兜底约定：写不进去的，**放 `tmp/writeback-pending/`**，并在回报里说清。
# 这条守门就判那个目录空不空——**空 = 没有挂账的回写**。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
D="tmp/writeback-pending"
n=0
[ -d "$D" ] && n=$(find "$D" -type f ! -name '.gitkeep' | wc -l)
if [ "$n" -gt 0 ]; then
  echo "  ✗  $D 里还挂着 $n 份没合进仓库的改动："
  find "$D" -type f ! -name '.gitkeep' | sed 's/^/     /' | head -20
  echo
  echo "WRITEBACK-FAIL（$n 份没写回）"
  echo "  开发席：按 docs/ops/realmachine.md 的四级办法再试一次（正常写回 → 改名法 → 换路径 → 申请权限）。"
  echo "  合进去之后把这个目录清空。**挂着不算交付完成。**"
  exit 1
fi
echo "WRITEBACK-OK（没有挂着的回写）"
