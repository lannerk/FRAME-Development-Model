#!/usr/bin/env bash
# check-cachebust: 前端的 `?v=` 版本串必须是**算出来的内容指纹**，不许人手编。
# 用法：bash ops/verify/check-cachebust.sh          只查
#       bash ops/verify/check-cachebust.sh --fix    就地改对（和 check-template-sync --accept 一个形状）
# 退出码 0 = 干净；1 = 有对不上的；2 = 结构不对。
#
# 【为什么要这条】页面里每个脚本后面挂一个 `?v=<号>`，用来让浏览器丢掉缓存。
# 改了脚本**不改这个号**，浏览器就一直用旧文件——**推上去了但没生效**：
# 文件确实换了、sha 对得上、日志也正常，是最难查的一类。
# 实测连报两次（改了的界面推上去就是不出现），而当时那条规矩
# **只是一句靠人记的话，没有任何脚本在查**。没有守门的规矩等于没有。
#
# 【判的是要保的那件事】判**版本串 ＝ 该文件内容的指纹**，不判「号码有没有往上加」。
# 人不再编号，也就没有"忘了改"这回事。指纹 ＝ sha256 前 8 位小写十六进制。
#
# 【三种都要说话，别只查一半】
#   ① 版本串和内容对不上（最常见的那一种：改了 js 忘了改号）；
#   ② 引用了一个**不存在**的 js（打错名字 / 文件删了没删引用）；
#   ③ 有这一族脚本但页面**一处都没引用**（加了文件忘了挂上去）；
#   ④ 引用了但**连 `?v=` 都没有**——那等于永远不失效，和 ① 是同一个坑。
#
# 【有原型镜像的项目】镜像那一份页面与源互为镜像，由 check-mirror 盯住「两边一致」；
# 这里只管源，`--fix` 之后把镜像重抄一遍即可。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
# 🔴 **项目专属的路径不许写死在 FRAME 里**（需求方 2026-09-26 拍板：「frame 也应该和具体项目无关」）：
# 值从 `ops/verify/paths.env` 读（一行一个 `KEY=值`，seed 类：模板里只有注释掉的样例），
# 也可以用环境变量临时盖过。**没配就跳过并说清怎么配**——不许报红：
# 一条不适用的守门报红，等于每个新项目开局就带一处假红，而假红的唯一修法是学会忽略它。
[ -f ops/verify/paths.env ] && . ops/verify/paths.env
WEB="${CACHEBUST_WEB:-}"
PAGE="${CACHEBUST_PAGE:-${WEB:+$WEB/index.html}}"
# 🔴 脚本名前缀是**每个项目自己的**约定，判据本身（版本串 ＝ 内容指纹）才是通用的——
# **项目专属的那一格必须是旋钮，不许写死。**
PREFIX="${CACHEBUST_PREFIX:-}"

# 三个旋钮：`CACHEBUST_WEB`（前端目录）· `CACHEBUST_PAGE`（挂脚本的那一页）·
# `CACHEBUST_PREFIX`（脚本名前缀）。**没配、页面不在、或这一族脚本一个都没有，就跳过**，不是报错。
if [ -z "$WEB" ] || [ -z "$PREFIX" ] || [ -z "$PAGE" ] || [ ! -f "$PAGE" ]; then
  echo "CACHEBUST-SKIP（未配置前端——在 ops/verify/paths.env 里写 CACHEBUST_WEB= / CACHEBUST_PREFIX=，或用环境变量）"; exit 0
fi

fp() { # 指纹 ＝ 内容 sha256 前 8 位。
  # 🔴 去掉 CR 再算：Windows 签出会把一边变成 CRLF，不去掉的话同一份内容在两台机器上指纹不同，
  # 这条守门就会在别人机器上无缘无故变红（check-mirror 踩过同一个坑）。
  tr -d '\r' < "$1" | sha256sum | cut -c1-8
}

FIX=0; [ "${1:-}" = "--fix" ] && FIX=1
bad=0; report=""; fixed=0

# ---- 逐条引用核指纹 ----
# 取出所有 <script src="<前缀>*.js..."> 的 src 原样（含或不含 ?v=）。
refs=$(grep -o "<script src=\"$PREFIX[^\"]*\"" "$PAGE" | sed 's/^<script src="//; s/"$//' | LC_ALL=C sort -u)
files=$(find "$WEB" -maxdepth 1 -type f -name "$PREFIX*.js" | LC_ALL=C sort)
# 引用和文件**两边都空**＝这个项目根本没有这一族脚本，跳过。
# 只有一边空是真问题：有文件没人引用（③）、或引用指向不存在的文件（②），下面逐条说话。
if [ -z "$refs" ] && [ -z "$files" ]; then
  echo "CACHEBUST-SKIP（$PAGE 里没有 $PREFIX*.js 的引用，$WEB/ 下也没有；用 CACHEBUST_PREFIX 指定你项目的前缀）"
  exit 0
fi

for ref in $refs; do
  file=${ref%%\?*}
  q=${ref#"$file"}                  # "" 或 "?v=xxx"
  path="$WEB/$file"
  if [ ! -f "$path" ]; then
    report="$report  ❌ $file —— index.html 引用了它，但 $WEB/ 下没有这个文件
"
    bad=$((bad+1)); continue
  fi
  want=$(fp "$path")
  if [ -z "$q" ]; then
    report="$report  ❌ $file —— 引用上**没有 ?v=**，等于这个文件的缓存永远不失效；应当是 ?v=$want
"
    bad=$((bad+1))
    [ "$FIX" = 1 ] && { sed -i "s|<script src=\"$file\"|<script src=\"$file?v=$want\"|g" "$PAGE"; fixed=$((fixed+1)); }
    continue
  fi
  have=${q#\?v=}
  if [ "$have" != "$want" ]; then
    report="$report  ❌ $file —— 版本串是 $have，按内容算应当是 $want（改了 js 没改版本串 ⇒ 浏览器还在用旧的）
"
    bad=$((bad+1))
    [ "$FIX" = 1 ] && { sed -i "s|<script src=\"$file?v=$have\"|<script src=\"$file?v=$want\"|g" "$PAGE"; fixed=$((fixed+1)); }
  fi
done

# ---- 有文件但没人引用 ----
while IFS= read -r path; do
  [ -n "$path" ] || continue
  n=$(basename "$path")
  grep -q "<script src=\"$n" "$PAGE" && continue
  report="$report  ❌ $n —— $WEB/ 下有这个文件，但 index.html 一处都没引用（加了文件忘了挂上去？）
"
  bad=$((bad+1))
done <<< "$files"

n=$(printf '%s\n' "$refs" | grep -c .)
if [ "$FIX" = 1 ] && [ "$fixed" -gt 0 ]; then
  echo "CACHEBUST-FIXED（改好了 $fixed 处；镜像那一份记得重抄，check-mirror 会盯）"
  # 改完自己再验一遍，免得 --fix 自己留下漏网的。
  exec bash "$0"
fi
if [ "$bad" -gt 0 ]; then
  printf '%s' "$report"
  echo "CACHEBUST-FAIL（$bad 处对不上；这一页共 $n 处引用）"
  echo "  怎么修：bash ops/verify/check-cachebust.sh --fix 然后把 $PAGE 抄一份到原型镜像"
  exit 1
fi
echo "CACHEBUST-OK（$n 处引用的版本串都等于文件内容的指纹）"
