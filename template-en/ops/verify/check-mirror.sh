#!/usr/bin/env bash
# check-mirror: the source and its prototype mirror may not drift apart.
# Usage: bash ops/verify/check-mirror.sh
#        bash ops/verify/check-mirror.sh --accept   record the current differences as the baseline (**it may only shrink**)
# Exit codes: 0 = no new drift; 1 = new drift, or the baseline should be narrowed; 2 = the structure is wrong.
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
  echo "MIRROR-SKIP (no mirror pair configured: $SRC <-> $DST do not exist; set MIRROR_SRC / MIRROR_DST)"; exit 0
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
  echo "baseline recorded in $BASE ($(grep -c . "$BASE" 2>/dev/null || echo 0) files allowed to differ)"
  echo "! The baseline **may only shrink**: align one file and delete its line. It is not a mute button."
  exit 0
fi

allowed() { [ -f "$BASE" ] && grep -qxF -- "$1" "$BASE"; }
while IFS= read -r n; do
  [ -n "$n" ] || continue
  la=$(wc -l < "$SRC/$n"); lb=$(wc -l < "$DST/$n")
  if allowed "$n"; then
    echo "  .  $n is still in the baseline (source $la lines / mirror $lb lines) -- pre-existing; the Reviewer seat aligns it"
  else
    echo "  x  the mirror drifted: $n (source $la lines / mirror $lb lines) -- mirror it in the same round you change the front end (conventions §4.22)"
    bad=$((bad+1))
  fi
done <<< "$drift"

# 基线只减不增：基线里已经对齐的，必须删掉那一行（否则基线会变成永久豁免）
if [ -f "$BASE" ]; then
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if [ -f "$SRC/$n" ] && [ -f "$DST/$n" ] && diff -q <(tr -d '\r' < "$SRC/$n") <(tr -d '\r' < "$DST/$n") >/dev/null 2>&1; then
      echo "  x  $n is aligned now but is still listed in $BASE -- delete that line (the baseline may only shrink)"; bad=$((bad+1))
    fi
  done < "$BASE"
fi

if [ "$bad" -gt 0 ]; then
  echo
  echo "MIRROR-FAIL ($bad)"
  echo "  The rule: when $SRC changes, mirror it to $DST in the same round (conventions §4.22). Pre-existing drift is in $BASE, which **may only shrink**."
  exit 1
fi
echo "MIRROR-OK (mirror matches source; $(grep -c . "$BASE" 2>/dev/null || echo 0) pre-existing files in the baseline await the Reviewer seat)"
