#!/usr/bin/env bash
# check-cachebust: the `?v=` version string on a front-end script must be a **computed content fingerprint**, never hand-written.
# Usage: bash ops/verify/check-cachebust.sh          check only
#        bash ops/verify/check-cachebust.sh --fix    rewrite them in place (same shape as check-template-sync --accept)
# Exit codes: 0 = clean; 1 = something does not match; 2 = the structure is wrong.
#
# 【为什么要这条】`index.html` 里每个 `inos-*.js` 后面挂一个 `?v=<号>`，用来让浏览器丢掉缓存。
# 改了 js **不改这个号**，浏览器就一直用旧文件——**推上去了但没生效**：
# 文件确实换了、sha 对得上、日志也正常，是最难查的一类。
# 开发席第八段（存储页横幅推上去就是不出现）、第九段连报两次，`conventions.md` §四 21 条
# 从写下那天起**只是一句靠人记的话，没有任何脚本在查**。没有守门的规矩等于没有。
#
# 【判的是要保的那件事】判**版本串 ＝ 该文件内容的指纹**，不判「号码有没有往上加」。
# 人不再编号，也就没有"忘了改"这回事。指纹 ＝ sha256 前 8 位小写十六进制。
#
# 【三种都要说话，别只查一半】
#   ① 版本串和内容对不上（最常见的那一种：改了 js 忘了改号）；
#   ② 引用了一个**不存在**的 js（打错名字 / 文件删了没删引用）；
#   ③ 有 `inos-*.js` 但 `index.html` **一处都没引用**（加了文件忘了挂上去）；
#   ④ 引用了但**连 `?v=` 都没有**——那等于永远不失效，和 ① 是同一个坑。
#
# 【镜像那一份】`product/design/prototype/inos/suite/AI-DESKTOP/index.html` 与源互为镜像，
# 由 check-mirror 盯住"两边一致"；这里只管源，`--fix` 之后把镜像重抄一遍即可。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
WEB="${CACHEBUST_WEB:-src/inos/web}"
PAGE="${CACHEBUST_PAGE:-$WEB/index.html}"
# 🔴 文件名前缀是**本项目的**约定（`inos-*.js`），模板里换个项目就不叫这个名。
# 判据本身（版本串 ＝ 内容指纹）是通用的，**项目专属的那一格必须是旋钮，不许写死**。
PREFIX="${CACHEBUST_PREFIX:-inos-}"

# 【新项目怎么办】三个旋钮：`CACHEBUST_WEB`（前端目录）· `CACHEBUST_PAGE`（挂脚本的那一页）·
# `CACHEBUST_PREFIX`（脚本名前缀）。**页面不在、或者这一族脚本一个都没有，就跳过**，不是报错——
# 一条不适用的守门不该拦住没有前端的项目，**也不该因为别人家的脚本不叫 `inos-` 就报红**。
if [ ! -f "$PAGE" ]; then
  echo "CACHEBUST-SKIP (no $PAGE; set CACHEBUST_WEB / CACHEBUST_PAGE)"; exit 0
fi

fp() { # 指纹 ＝ 内容 sha256 前 8 位。
  # 🔴 去掉 CR 再算：Windows 签出会把一边变成 CRLF，不去掉的话同一份内容在两台机器上指纹不同，
  # 这条守门就会在别人机器上无缘无故变红（check-mirror 踩过同一个坑）。
  tr -d '\r' < "$1" | sha256sum | cut -c1-8
}

FIX=0; [ "${1:-}" = "--fix" ] && FIX=1
bad=0; report=""; fixed=0

# ---- 逐条引用核指纹 ----
# 取出所有 <script src="inos-*.js..."> 的 src 原样（含或不含 ?v=）。
refs=$(grep -o "<script src=\"$PREFIX[^\"]*\"" "$PAGE" | sed 's/^<script src="//; s/"$//' | LC_ALL=C sort -u)
files=$(find "$WEB" -maxdepth 1 -type f -name "$PREFIX*.js" | LC_ALL=C sort)
# 引用和文件**两边都空**＝这个项目根本没有这一族脚本，跳过。
# 只有一边空是真问题：有文件没人引用（③）、或引用指向不存在的文件（②），下面逐条说话。
if [ -z "$refs" ] && [ -z "$files" ]; then
  echo "CACHEBUST-SKIP ($PAGE references no $PREFIX*.js and $WEB/ has none; set CACHEBUST_PREFIX to your project prefix)"
  exit 0
fi

for ref in $refs; do
  file=${ref%%\?*}
  q=${ref#"$file"}                  # "" 或 "?v=xxx"
  path="$WEB/$file"
  if [ ! -f "$path" ]; then
    report="$report  x $file -- the page references it, but $WEB/ has no such file
"
    bad=$((bad+1)); continue
  fi
  want=$(fp "$path")
  if [ -z "$q" ]; then
    report="$report  x $file -- the reference carries **no ?v= at all**, so this file is cached forever; it should be ?v=$want
"
    bad=$((bad+1))
    [ "$FIX" = 1 ] && { sed -i "s|<script src=\"$file\"|<script src=\"$file?v=$want\"|g" "$PAGE"; fixed=$((fixed+1)); }
    continue
  fi
  have=${q#\?v=}
  if [ "$have" != "$want" ]; then
    report="$report  x $file -- the version string is $have; computed from its content it should be $want (changed the js, left the string => the browser keeps the old file)
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
  report="$report  x $n -- $WEB/ has this file, but the page never references it (added the file, forgot to hook it up?)
"
  bad=$((bad+1))
done <<< "$files"

n=$(printf '%s\n' "$refs" | grep -c .)
if [ "$FIX" = 1 ] && [ "$fixed" -gt 0 ]; then
  echo "CACHEBUST-FIXED ($fixed rewritten; re-copy the mirror as well -- check-mirror is watching)"
  # 改完自己再验一遍，免得 --fix 自己留下漏网的。
  exec bash "$0"
fi
if [ "$bad" -gt 0 ]; then
  printf '%s' "$report"
  echo "CACHEBUST-FAIL ($bad wrong; $n references on the page)"
  echo "  How to fix: bash ops/verify/check-cachebust.sh --fix, then copy $PAGE over to the prototype mirror"
  exit 1
fi
echo "CACHEBUST-OK (all $n referenced version strings equal their file content fingerprint)"
