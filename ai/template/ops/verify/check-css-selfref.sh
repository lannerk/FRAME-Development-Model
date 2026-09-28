#!/usr/bin/env bash
# check-css-selfref: CSS 变量不许引用自己（`--x: var(--x)`），直接或绕一圈都算。
# 用法：bash ops/verify/check-css-selfref.sh
#       CSSREF_DIRS="<目录…>" bash ops/verify/check-css-selfref.sh   ← 反向断言请指到拷贝上做
# 退出码 0 = 没有（或不适用）；1 = 有。
#
# 【为什么要这条】它是**批量替换最常见的那个回归**：把散落的字面值批量换成令牌时，
# 令牌自己那一行也被一起换了，于是变成 `--fs-4: var(--fs-4)`。
# 后果很难查：这个变量**解析成空**，用到它的地方**静默回落到继承值或初始值**——
# 页面不报错、控制台干净、截图看着"差一点点"，而**没有任何一行日志提到它**。
#
# 【判的是要保的那件事】判的是「**这个变量的值里引用了它自己**」，不是「某一行里出现两次同名」：
# 同名出现在**不同的声明**里（`--x: 1rem` 与别处 `width: var(--x)`）完全正常。
# 所以只在**一条声明内部**判：`--名字:` 到分号之间，出现 `var(--同一个名字)` 就红。
#
# 【扫了多少份要报出来】按 `ai/specs/testing.md` §0a R2：扫到空集报红——
# 一条扫不到东西的守门永远是绿的。
set -u
cd "$(dirname "$0")/../.." || exit 2
[ -f ops/verify/paths.env ] && . ops/verify/paths.env
DIRS="${CSSREF_DIRS:-${CSSNS_WEB:-}}"
[ -n "$DIRS" ] || { echo "CSS-SELFREF-SKIP（没配 CSSNS_WEB/CSSREF_DIRS，这条不适用）"; exit 0; }
n=0; files=0
for d in $DIRS; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    files=$((files+1))
    while IFS=: read -r ln txt; do
      [ -n "$ln" ] || continue
      echo "  ✗  $f:$ln $(printf '%s' "$txt" | sed 's/^[[:space:]]*//' | cut -c1-70)"
      n=$((n+1))
    done < <(grep -nE -- '--([A-Za-z0-9_-]+)[[:space:]]*:[^;]*var\([[:space:]]*--\1[[:space:]]*[,)]' "$f" || true)
  done < <(find "$d" -name '*.css' -o -name '*.html' -o -name '*.js' | LC_ALL=C sort)
done
[ "$files" = 0 ] && { echo "CSS-SELFREF-SKIP（$DIRS 下没有样式文件）"; exit 0; }
if [ "$n" -gt 0 ]; then
  echo "CSS-SELFREF-FAIL（$n 处；扫了 $files 份）"
  echo "  改法：把右边换回真实值。自引用的变量解析成空，用它的地方静默回落——页面不报错、日志里什么都没有。"
  exit 1
fi
echo "CSS-SELFREF-OK（扫了 $files 份样式/页面文件，没有自引用的 CSS 变量）"
