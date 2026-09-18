#!/usr/bin/env bash
# check-all: 一次跑完所有守门，只输出一张表。
# 用法：bash ops/verify/check-all.sh          全跑
#       bash ops/verify/check-all.sh -v       红的那几条连详情一起打出来
# 退出码 0 = 全绿；1 = 有红的。
#
# 【为什么要这条】需求方说「我觉得开发跑偏了，你查一下」的时候，
# 维护席不该把七八个脚本的输出一条条读进上下文——那是纯烧 token。
# 这一份把能机器判的**一次跑完**，只回一张表；**只有红的才值得人去看**。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
V=0; [ "${1:-}" = "-v" ] && V=1
pass=0; fail=0; out=""

run() { # $1=名字 $2...=命令
  local name="$1"; shift
  local o rc
  o=$("$@" 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '  ✅ %-22s %s\n' "$name" "$(tail -1 <<< "$o")"
    pass=$((pass+1))
  else
    # 红行的摘要取**判据行**（`*-FAIL…`），不是倒数第二行——
    # 后者会取到空行或提示语（实测：台账对账那一格一直是空白）。**四席都会读这张表，摘要必须说出「几处」。**
    local sum; sum=$(grep -E '\-FAIL' <<< "$o" | tail -1); [ -n "$sum" ] || sum=$(tail -2 <<< "$o" | head -1)
    printf '  ❌ %-22s %s\n' "$name" "$sum"
    fail=$((fail+1))
    out="$out
── $name ──
$o"
  fi
}

echo "守门巡检 · $(date '+%Y-%m-%d %H:%M')"
echo
[ -x ai/check-links.sh ]                  && run "引用完整性"   bash ai/check-links.sh
[ -x ops/verify/check-paths.sh ]          && run "写死的路径与IP" bash ops/verify/check-paths.sh
[ -x ops/verify/check-inbox.sh ]          && run "收件簿"       bash ops/verify/check-inbox.sh
[ -x ops/verify/check-bugs.sh ]           && run "bug 闭环"     bash ops/verify/check-bugs.sh
[ -x ops/verify/check-ledger.sh ]         && run "台账对账"     bash ops/verify/check-ledger.sh
[ -x ops/verify/check-budget.sh ]         && run "行数预算"     bash ops/verify/check-budget.sh
[ -x ops/verify/check-filenames.sh ]      && run "文件名跨平台" bash ops/verify/check-filenames.sh
[ -x ops/verify/check-entrypoints.sh ]    && run "入口文件"     bash ops/verify/check-entrypoints.sh
[ -x ops/verify/check-root.sh ]           && run "仓库根白名单"   bash ops/verify/check-root.sh
[ -x ops/verify/check-css-namespace.sh ]  && run "CSS 类名撞车"    bash ops/verify/check-css-namespace.sh
[ -x ops/verify/check-mirror.sh ]         && run "源与镜像"       bash ops/verify/check-mirror.sh
[ -x ops/verify/check-mail.sh ]           && run "席间信箱"       bash ops/verify/check-mail.sh
[ -x ops/verify/check-writeback.sh ]      && run "回写待合"     bash ops/verify/check-writeback.sh
[ -x ops/verify/check-template-sync.sh ]  && run "模板同步"     bash ops/verify/check-template-sync.sh

echo
if [ "$fail" -gt 0 ]; then
  [ "$V" = 1 ] && { echo "$out"; echo; }
  echo "ALL-FAIL（$pass 绿 / $fail 红）"
  [ "$V" = 0 ] && echo "  看详情：bash ops/verify/check-all.sh -v"
  exit 1
fi
echo "ALL-OK（$pass 条守门全绿）"
