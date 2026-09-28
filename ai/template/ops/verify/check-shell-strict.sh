#!/usr/bin/env bash
# check-shell-strict: 开了 `set -u` 的脚本里，**某个函数裸读 $1，而它至少有一处调用不带参数**。
# 用法：bash ops/verify/check-shell-strict.sh
#       SHELL_STRICT_DIRS="<目录…>" bash ops/verify/check-shell-strict.sh   ← 反向断言请指到拷贝上做
# 退出码 0 = 没有这种形状（或不适用）；1 = 有。
#
# 【为什么要这条】实测一次、代价很高：一份公共脚本开头 `set -eu`，某个函数里 `local q=$1`，
# 而有一处调用**不带参数** —— `set -u` 判「未绑定变量」，`set -e` 让脚本**当场退出**，
# 于是那台机器上依赖它的**安装全部失败**，日志里只有一行 unbound variable：
# 看不出是哪个函数，更看不出是哪一次调用。**改法一个字符：`${1:-}`。**
#
# 【判的是要保的那件事，不是它的文本影子】
# 🔴 第一版判「函数里出现裸 $1」，在本仓库报了 **55 处、几乎全是假红**：
# `awk '{print $2}'` 里的 `$2` 是 awk 的字段、不是位置参数；而**必填参数**裸读本来就没问题
# （调用方永远会传）。一条上线就带着几十处历史红的判据，**下场一定是被一键消音**。
# 所以判据收到实测那次的形状：**定义处裸读 $1** ＋ **同一份文件里至少一处调用它时一个参数都不带**。
# 这一对同时成立，才是「少传一个参数就整份退出」的那件事。
#
# 【扫了多少份要报出来】按 `ai/specs/testing.md` §0a R2：**扫到空集就报红**——
# 一条扫不到东西的守门永远是绿的，而那是最危险的绿。
set -u
cd "$(dirname "$0")/../.." || exit 2
DIRS="${SHELL_STRICT_DIRS:-ops src scripts bin}"
n=0; files=0
for d in $DIRS; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    grep -qE '^[[:space:]]*set[[:space:]]+-[a-z]*u' "$f" || continue   # 没开 -u，这条不适用
    files=$((files+1))
    out="$(awk '
      # ── 第一遍：哪些函数在定义处裸读了 $1（跳过单引号里的 awk/sed 程序体）──
      function strip(s,   r) { r=s; gsub(/#.*/,"",r); gsub(/'"'"'[^'"'"']*'"'"'/,"",r); return r }
      /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/ {
        fname=$0; sub(/[[:space:]]*\(\).*/,"",fname); gsub(/^[[:space:]]+/,"",fname)
        cur=fname; next
      }
      cur != "" {
        l=strip($0)
        if (l ~ /\$1([^:={+?\-0-9]|$)/ || l ~ /\$\{1\}/) bare[cur]=1
        if ($0 ~ /^\}/) cur=""
      }
      # ── 第二遍靠同一次扫描的第二个数组：调用处 ──
      { lines[NR]=$0 }
      END {
        for (i=1;i<=NR;i++) {
          # 🔴 调用处只去注释，**不去单引号**：`foo ''` 是**传了一个空串**，不是不带参数。
          # （第一版在这儿用了和定义扫描同一个 strip，把 '' 抹掉之后判成「不带参数」——假红。）
          l=lines[i]; sub(/#.*/,"",l)
          if (l ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/) continue   # 定义行不算调用
          for (fn in bare) {
            # 调用形状：行首（可带缩进）或 && || ; 之后，函数名后面直到行尾/管道/分号都没有参数
            pat="(^|;|&&|\\|\\||\\{)[[:space:]]*" fn "[[:space:]]*(;|&&|\\|\\||$|#|\\))"
            if (l ~ pat) printf "%d: %s  ←  函数 %s 裸读 $1，这一处调用不带参数\n", i, lines[i], fn
          }
        }
      }' "$f")"
    [ -n "$out" ] || continue
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      echo "  ✗  $f:$h"
      n=$((n+1))
    done <<< "$out"
  done < <(find "$d" -name '*.sh' -type f | LC_ALL=C sort)
done
if [ "$files" = 0 ]; then
  echo "SHELL-STRICT-SKIP（$DIRS 下没有开 set -u 的 .sh —— 这条不适用）"; exit 0
fi
if [ "$n" -gt 0 ]; then
  echo "SHELL-STRICT-FAIL（$n 处；扫了 $files 份开了 set -u 的脚本）"
  echo "  改法：那个函数里把 \$1 写成 \${1:-}（必填就写 \${1:?缺参数}），或者调用处把参数补上。"
  exit 1
fi
echo "SHELL-STRICT-OK（扫了 $files 份开了 set -u 的脚本，没有「函数裸读 \$1 ＋ 有一处调用不带参数」的形状）"
