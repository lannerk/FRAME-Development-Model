#!/usr/bin/env bash
# frame-scan: 初始化项目时用——把根目录下的东西分成「我们的」和「旧项目的」。
# 用法：bash ops/verify/frame-scan.sh
# 退出码 0 = 扫完了（0 不代表"没问题"，只代表扫完了，结果要人看）。
#
# 背景：这套模板是**整个根目录覆盖**上去的。覆盖完根目录里混着两拨东西，
# 而新项目里没有模板可以拿来比——尺子是 ai/frame-manifest.txt（由模板自动生成）。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
M="ai/frame-manifest.txt"
[ -f "$M" ] || { echo "找不到 $M —— 这份清单随模板一起来，丢了就没法分辨谁是谁。"; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
grep -v '^#' "$M" | grep -v '^[[:space:]]*$' | LC_ALL=C sort > "$TMP/ours"
find . -type f \
  -not -path './.git/*' -not -path './archive/*' \
  -not -path './dist/*'  -not -path './tmp/*' \
  -printf '%P\n' | LC_ALL=C sort > "$TMP/actual"

comm -12 "$TMP/ours" "$TMP/actual" > "$TMP/A"
comm -13 "$TMP/ours" "$TMP/actual" > "$TMP/B"
comm -23 "$TMP/ours" "$TMP/actual" | grep -Ev '^(archive|dist|tmp)/' > "$TMP/missing" || true

echo "=== A · 我们的（清单里有，现在也在）：$(wc -l < "$TMP/A") 份 ==="
echo "    不动。但其中**内容像旧项目的那几份就是 C 类撞名**，务必逐个看："
echo "    最常撞的：README.md  .gitignore  docs/  src/ 下面的东西"
echo
echo "=== B · 旧项目的（清单里没有）：$(wc -l < "$TMP/B") 份 ==="
echo "    按 ai/rules/layout.md 归类迁移。先出映射表给需求方确认，再动手。"
if [ -s "$TMP/B" ]; then
  echo "    —— 顶层先看这些："
  sed 's|/.*||' "$TMP/B" | LC_ALL=C sort -u | sed 's/^/      /'
  echo "    —— 全部（前 200 行）："
  head -200 "$TMP/B" | sed 's/^/      /'
  [ "$(wc -l < "$TMP/B")" -gt 200 ] && echo "      …… 还有 $(( $(wc -l < "$TMP/B") - 200 )) 份，自己读 $M 比"
fi
echo
echo "=== 清单里有、现在却没有：$(wc -l < "$TMP/missing") 份 ==="
echo "    多半是覆盖没覆盖全，或者被旧项目的同名东西挤掉了。**逐个查清楚再往下走。**"
[ -s "$TMP/missing" ] && sed 's/^/      /' "$TMP/missing"
echo
echo "注意：archive/ dist/ tmp/ 没扫（它们本来就装杂物）。"
echo "FRAME-SCAN-DONE（这是「扫完了」，不是「没问题」——结果要人看）"
