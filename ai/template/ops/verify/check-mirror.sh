#!/usr/bin/env bash
# check-mirror: 源与原型镜像不许漂。
# 用法：bash ops/verify/check-mirror.sh
#       bash ops/verify/check-mirror.sh --accept   把当前的差异记成基线（**只许缩小**）
# 退出码 0 = 没有新漂移；1 = 有新漂移或基线该收窄；2 = 结构不对。
#
# 【为什么要这条】`ai/rules/conventions.md` §四.22 要求「改前端当轮写回 `src/inos/web/` 并镜像到
# `product/design/prototype/inos/suite/AI-DESKTOP/`」，而**这条规矩从写下那天起没有任何脚本在查**。
# 开发席 2026-09-16 实测：HEAD 上已经漂了三份（`inos-files.js` -897 行、`inos-voice.js` -162、`inos-ui.js` -105）。
# **没有守门的规矩等于没有**——这是这套方法自己的判据。
#
# 【判的是要保的那件事】判**镜像与源逐字节一致**，不判「有没有人记得抄」。
# 只判「镜像目录里已经有的同名文件」：新增文件该不该进原型是人的判断，不是守门的。
#
# 【存量怎么办】开发席原话：「红了却没人能修，等于噪声」。所以带一份基线
# `ops/verify/.mirror-baseline`：里面的文件**允许差**，但**只许缩小**——
# 基线里的文件哪天对齐了，守门会让你把它从基线里删掉（基线只减不增，减了就回不去）。
# 存量归零归**审查席**（`product/*` 按 `ai/rules/layout.md` §七 是它的），不是守门的活。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
SRC="${MIRROR_SRC:-src/inos/web}"
DST="${MIRROR_DST:-product/design/prototype/inos/suite/AI-DESKTOP}"
BASE="${MIRROR_BASE:-ops/verify/.mirror-baseline}"
# 【新项目怎么办】这一对路径是项目专属的（本项目：前端源 ↔ 原型镜像）。
# 两边都不存在就**跳过**，不是报错——**模板里没有镜像对的项目不该被一条不适用的守门拦住**；
# 要用就在跑的时候给 MIRROR_SRC / MIRROR_DST，或者把默认值改成你项目的那一对。
if [ ! -d "$SRC" ] || [ ! -d "$DST" ]; then
  echo "MIRROR-SKIP（没有配置镜像对：$SRC ↔ $DST 不存在；用 MIRROR_SRC / MIRROR_DST 指定）"; exit 0
fi
bad=0; drift=""

while IFS= read -r b; do
  n=$(basename "$b")
  a="$SRC/$n"
  [ -f "$a" ] || continue                     # 镜像里有、源里没有：那是原型自己的东西，不判
  # 【别判行尾】Windows 签出会把一边变成 CRLF，**逐字节比会把「只差行尾」判成漂移**
  # （首跑就抓到 logo.html / orb-states.html / share.html 三份：行数一样、内容一样，只差 CR）。
  # 判的是内容一致，不是字节一致——去掉 CR 再比。
  diff -q <(tr -d '\r' < "$a") <(tr -d '\r' < "$b") >/dev/null 2>&1 && continue
  drift="$drift$n
"
done < <(find "$DST" -maxdepth 1 -type f \( -name '*.js' -o -name '*.html' -o -name '*.css' \) | LC_ALL=C sort)
drift=$(printf '%s' "$drift" | grep . || true)

if [ "${1:-}" = "--accept" ]; then
  printf '%s\n' "$drift" | grep . > "$BASE" || : > "$BASE"
  echo "已记基线 $BASE（$(grep -c . "$BASE" 2>/dev/null || echo 0) 份允许差）"
  echo "⚠ 基线**只许缩小**：对齐一份就从里面删一行。它不是「让检查闭嘴」的开关。"
  exit 0
fi

allowed() { [ -f "$BASE" ] && grep -qxF -- "$1" "$BASE"; }
while IFS= read -r n; do
  [ -n "$n" ] || continue
  la=$(wc -l < "$SRC/$n"); lb=$(wc -l < "$DST/$n")
  if allowed "$n"; then
    echo "  ·  $n 仍在基线里（源 $la 行 / 镜像 $lb 行）—— 存量，归审查席对齐"
  else
    echo "  ✗  镜像漂了：$n（源 $la 行 / 镜像 $lb 行）—— 改前端要当轮镜像（conventions §四.22）"
    bad=$((bad+1))
  fi
done <<< "$drift"

# 基线只减不增：基线里已经对齐的，必须删掉那一行（否则基线会变成永久豁免）
if [ -f "$BASE" ]; then
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if [ -f "$SRC/$n" ] && [ -f "$DST/$n" ] && diff -q <(tr -d '\r' < "$SRC/$n") <(tr -d '\r' < "$DST/$n") >/dev/null 2>&1; then
      echo "  ✗  $n 已经对齐了，但还留在基线 $BASE 里 —— 删掉那一行（基线只许缩小）"; bad=$((bad+1))
    fi
  done < "$BASE"
fi

if [ "$bad" -gt 0 ]; then
  echo
  echo "MIRROR-FAIL（$bad 处）"
  echo "  规矩：$SRC 改了，当轮镜像到 $DST（conventions §四.22）。存量在 $BASE，**只许缩小**。"
  exit 1
fi
echo "MIRROR-OK（镜像与源一致；基线里 $(grep -c . "$BASE" 2>/dev/null || echo 0) 份存量待审查席对齐）"
