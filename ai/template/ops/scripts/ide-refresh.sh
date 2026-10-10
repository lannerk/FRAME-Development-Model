#!/usr/bin/env bash
# ide-refresh：看 ai/ide/ 里各工具的实现文件该不该更新（ai/ide/README.md §三 第 1 步）。
# 用法：bash ops/scripts/ide-refresh.sh <工具>|--all
# 只做三件：有 npm 包的拿 `npm view` 和头部 version: 比；没有的印 version-url 让人去看；checked: 超过 90 天标「久没核」。最后印要重读的 docs:。
# 【为什么只做这些】它跑在仓库里，查不了网页（各家文档站常禁抓、路径常改）；版本号是唯一能稳定判的。文档变没变，照 README §三 第 2 步人读。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
DIR="${IDE_DIR:-ai/ide}"
hdr(){ awk 'NR==1 && /^---[[:space:]]*$/ {f=1; next} f && /^---[[:space:]]*$/ {exit} f {print}' "$1"; }
hval(){ hdr "$1" | grep -E "^$2:" | head -1 | sed "s/^$2:[[:space:]]*//; s/[[:space:]]*#.*$//; s/^\"//; s/\"$//"; }
[ $# -ge 1 ] || { echo "用法：bash ops/scripts/ide-refresh.sh <工具>|--all"; exit 2; }
if [ "$1" = --all ]; then
  set -- $(for f in "$DIR"/*.md; do [ -f "$f" ] && b=$(basename "$f" .md) && [ "$b" != README ] && echo "$b"; done)
  [ $# -ge 1 ] || { echo "$DIR 里没有实现文件"; exit 2; }
fi
now=$(date +%s)
for t in "$@"; do
  f="$DIR/$t.md"; [ -f "$f" ] || f="$DIR/_spare/$t.md"
  [ -f "$f" ] || { echo "✗ $t：$DIR 里没有这份实现文件"; continue; }
  npm="$(hval "$f" npm)"; ver="$(hval "$f" version)"; chk="$(hval "$f" checked)"; vurl="$(hval "$f" version-url)"
  out="$t（记的 ${ver:-?}，${chk:-?} 核）"
  if [ -n "$npm" ] && [ "$npm" != none ] && command -v npm >/dev/null 2>&1; then
    cur="$(timeout 30 npm view "$npm" version 2>/dev/null | tail -1)"
    if [ -z "$cur" ]; then out="$out：npm 查不到（没网，或包改名了）"
    elif [ "$cur" = "$ver" ]; then out="$out：没变"
    else out="$out：变了 $ver → $cur，照 $DIR/README.md §三 第 2 步核"; fi
  else out="$out：没有 npm 包（或这里没装 npm），去看一眼 ${vurl:-（头部没写 version-url）}"; fi
  if ts=$(date -d "$chk" +%s 2>/dev/null); then d=$(( (now - ts) / 86400 )); [ "$d" -gt 90 ] && out="$out · ⚠ 久没核（$d 天）"; fi
  echo "$out"
  hdr "$f" | awk '/^docs:/ {f=1; next} f && /^[[:space:]]+- / {sub(/^[[:space:]]+- /, "    重读："); print; next} f {exit}'
done
