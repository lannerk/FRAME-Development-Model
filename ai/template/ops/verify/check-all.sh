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
# 【每跑一次都把结果存进 tmp/.check-all.last】（第一行：开始时刻的 epoch 与 HEAD，下面是整张表）
# 提交脚本 20 分钟内直接用它，不再现跑一遍——挂载盘上这张表要跑两分钟，提交时再跑一遍会让一次调用超时、被杀、留锁
# （审查席 2026-09-30 实测）。存的是「开跑时刻」，偏保守。
if [ -z "${CHECK_ALL_INNER:-}" ]; then
  # 🔴 **先写进本次独有的临时文件，再整份改名覆盖**：几席同时跑巡检是常态，共用一个中间文件会互相截断、
  # 写出带 NUL 空洞的结果（维护席 2026-09-30 实测：一份 .last 里 653 个 NUL、前 6 格整行丢失，提交脚本读不出判据行）。
  mkdir -p tmp; t0=$(date +%s); body="$(mktemp "${TMPDIR:-/tmp}/check-all.XXXXXX")"
  CHECK_ALL_INNER=1 bash "$0" "$@" | tee "$body"; rc=${PIPESTATUS[0]}
  nf="$(mktemp tmp/.check-all.last.XXXXXX)" && { echo "$t0 $(git rev-parse --short HEAD 2>/dev/null)"; cat "$body"; } > "$nf" && mv -f "$nf" tmp/.check-all.last
  rm -f "$body" 2>/dev/null
  exit "$rc"
fi
V=0; [ "${1:-}" = "-v" ] && V=1
pass=0; fail=0; out=""

run() { # $1=名字 $2...=命令
  local name="$1"; shift
  local o rc t1 dt
  t1=$(date +%s); o=$("$@" 2>&1); rc=$?; dt=$(( $(date +%s) - t1 ))
  # 每格带耗时：挂载盘上最慢的几道（台账对账、引用完整性）要算进「一次调用 180 s」里，看得见才管得住
  if [ "$rc" -eq 0 ]; then
    printf '  ✅ %-22s %s（%ss）\n' "$name" "$(tail -1 <<< "$o")" "$dt"
    pass=$((pass+1))
  else
    # 红行的摘要取**判据行**（`*-FAIL…`），不是倒数第二行——
    # 后者会取到空行或提示语（实测：台账对账那一格一直是空白）。**四席都会读这张表，摘要必须说出「几处」。**
    local sum; sum=$(grep -E '\-FAIL' <<< "$o" | tail -1); [ -n "$sum" ] || sum=$(tail -2 <<< "$o" | head -1)
    printf '  ❌ %-22s %s（%ss）\n' "$name" "$sum" "$dt"
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
[ -x ops/verify/check-cachebust.sh ]     && run "前端缓存串"   bash ops/verify/check-cachebust.sh
[ -x ops/verify/check-randd.sh ]         && run "R&D 线"         bash ops/verify/check-randd.sh
[ -x ops/verify/check-frame-version.sh ] && run "FRAME 版本"  bash ops/verify/check-frame-version.sh
[ -x ops/verify/check-shell-strict.sh ] && run "shell 严格模式" bash ops/verify/check-shell-strict.sh
[ -x ops/verify/check-css-selfref.sh ]  && run "CSS 变量自引用" bash ops/verify/check-css-selfref.sh
[ -x ops/verify/check-advisor.sh ]       && run "开场顾问"      bash ops/verify/check-advisor.sh
[ -x ops/verify/check-debrand.sh ]       && run "去品牌  "      bash ops/verify/check-debrand.sh

# ── 🔴 项目自己的守门：`ops/verify/check-project-*.sh` 自动发现 ────────────────
# 【为什么要这个口子】上面这张表是 **FRAME 本体**的（follow 类，同步会覆盖）。一个项目必然会长出
# 只对它成立的守门（组件清单、接口对账、词表……），而**在这张表里加一行 = 把项目内容写进 FRAME**：
# 实测过一次——某个项目的维护席为了注册自己的守门改了 check-all.sh，于是这份文件在它那里变成
# 「目标改过」，**每次分发都要人来合一次**，而合进模板又会把那个项目的守门推给所有项目。
# 所以口子开在**文件名**上，不开在表里：`ops/verify/check-project-*.sh` 放进去就自动跑，
# 名字里带 `project` 是提醒——**它永不进模板**（`ops/frame/classes.txt` 里是 skip 类）。
# 约定与上面各条一样：绿了打印一行 `*-OK`，红了 exit 非 0，不适用就 SKIP 别报红。
for pc in ops/verify/check-project-*.sh; do
  [ -x "$pc" ] || continue
  run "项目守门" bash "$pc"
done

echo
if [ "$fail" -gt 0 ]; then
  [ "$V" = 1 ] && { echo "$out"; echo; }
  echo "ALL-FAIL（$pass 绿 / $fail 红 · 共 ${SECONDS}s）"
  [ "$V" = 0 ] && echo "  看详情：bash ops/verify/check-all.sh -v"
  exit 1
fi
echo "ALL-OK（$pass 条守门全绿 · 共 ${SECONDS}s）"
