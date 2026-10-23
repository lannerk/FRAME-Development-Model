#!/usr/bin/env bash
# check-frame-version: FRAME 本体改了，版本号有没有跟着盖。
# 用法：bash ops/verify/check-frame-version.sh
#       FV_ROOT=<另一个仓库根> bash ops/verify/check-frame-version.sh   ← 反向断言请指到拷贝上做
# 退出码 0 = 版本跟上了（或不适用）；1 = FRAME 本体有提交晚于最后一次盖版本；2 = 结构不对。
#
# 【为什么要这条】「指纹给机器判，版本号人 bump」——而人会忘。规矩原来只写在口令「同步 FRAME」的第 8 步，
# 维护席**直接改源仓库、不走那个口令**时就没有任何东西提醒它（2026-09-28 实测：改了 layout.md、提交了、没 bump，
# 需求方一眼看出来：「你更新源FRAME不更新版本号码」）。下游拿版本号判「我跟上了没有」，版本不动＝改动对人不可见。
#
# 【判的是要保的那件事】不比 mtime、不比指纹：比 **git 提交顺序**——
# FRAME 本体（`ops/frame/classes.txt` 判成 follow 的文件，版本文件自己除外）最后一次提交，
# 必须**就是**或**早于**最后一次改 `ai/FRAME-VERSION` 的那次提交。同一次提交里一起改了算跟上。
# 没提交的改动不管（那是提交时的事）；带模板的仓库对每份模板各跑一次（在模板目录里跑）。
set -u
export GIT_OPTIONAL_LOCKS=0
ROOT="${FV_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$ROOT" || exit 2
CL="ops/frame/classes.txt"; MF="ai/frame-manifest.txt"; VF="ai/FRAME-VERSION"
[ -f "$CL" ] && [ -f "$MF" ] || { echo "FRAME-VERSION-SKIP（没有 $CL 或 $MF，不是 FRAME 仓库）"; exit 0; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "FRAME-VERSION-SKIP（不在 git 里）"; exit 0; }
# 分类只问 `ops/frame/frame-sync.sh --classify`（FRAME 1.11.0：分类只有一处出处）——**不在这里再抄一份 glob 匹配**，
# 抄一份就是两套判据，改了 classes.txt 只有一边跟上，而两边不一致没有任何症状（这份脚本 1.7.0 版就抄过一份）。
[ -f ops/frame/frame-sync.sh ] || { echo "FRAME-VERSION-SKIP（没有 ops/frame/frame-sync.sh）"; exit 0; }
F=()
while IFS=$'\t' read -r cls rel; do
  rel="${rel%$'\r'}"; [ "$cls" = follow ] || continue
  [ "$rel" = "$VF" ] && continue; [ -f "$rel" ] || continue
  F+=("$rel")
done < <(bash ops/frame/frame-sync.sh --classify 2>/dev/null)
[ "${#F[@]}" -gt 0 ] || { echo "FRAME-VERSION-SKIP（清单里没有 follow 类文件）"; exit 0; }
lf="$(git log -1 --format=%H -- "${F[@]}" 2>/dev/null)"
[ -n "$lf" ] || { echo "FRAME-VERSION-OK（FRAME 本体还没有提交）"; exit 0; }
lv="$(git log -1 --format=%H -- "$VF" 2>/dev/null)"
ver="$(grep -E '^version:' "$VF" 2>/dev/null | head -1 | awk '{print $2}')"
if [ -n "$lv" ] && git merge-base --is-ancestor "$lf" "$lv" 2>/dev/null; then
  echo "FRAME-VERSION-OK（${#F[@]} 份 FRAME 本体，最后一次提交已盖在 ${ver:-?} 里）"; exit 0
fi
# 【提交顺序反了、版本其实盖对了】别席用 --all-seats 把盖好的 `ai/FRAME-VERSION` 先一步带进它的提交，本体晚一笔才提交——
# 上面那条按提交顺序判就红了，可重盖一次文件一字不变，没有东西可提交，**这条红用正当手段消不掉**（Frey 2026-10-23 实测：
# d0e87a4 带走 2.6.1，c8c349b 才提交本体）。要保的那件事是「本体的每一处改动都被一个版本号覆盖」：
# **本体与版本文件都没有未提交改动，且版本文件记的指纹等于现算的指纹**，就是覆盖了。指纹由 frame-sync 现算，不在这里抄算法。
if [ -n "$lv" ] && git diff --quiet HEAD -- "${F[@]}" 2>/dev/null; then
  rec="$(grep -E '^fingerprint:' "$VF" 2>/dev/null | head -1 | awk '{print $2}')"
  cur="$(bash ops/frame/frame-sync.sh --status 2>/dev/null | grep -E '^(版本|version) ' | grep -oE '[0-9a-f]{16}$' | head -1)"
  if [ -n "$rec" ] && [ "$rec" = "$cur" ] && git diff --quiet HEAD -- "$VF" 2>/dev/null; then
    echo "FRAME-VERSION-OK（${#F[@]} 份 FRAME 本体；版本文件比本体早一笔提交，但记的指纹 $rec 就是已提交本体的指纹，算已盖在 ${ver:-?} 里）"; exit 0
  fi
fi
echo "  ✗  FRAME 本体最后一次提交 $(git log -1 --format='%h %ad「%s」' --date=format:'%m-%d %H:%M' "$lf" | cut -c1-90)"
echo "     晚于最后一次盖版本 ${lv:+$(git log -1 --format='%h %ad' --date=format:'%m-%d %H:%M' "$lv")}（现在是 ${ver:-没有版本文件}）"
echo "     那次动到的 FRAME 本体：$(git show --name-only --format= "$lf" -- "${F[@]}" | head -5 | tr '\n' ' ')"
echo "     补法：维护席按「结构/角色变=major · 规矩语义变=minor · 措辞=patch」定号，bash ops/frame/frame-sync.sh --stamp <版本>，提交信息带版本号"
echo "FRAME-VERSION-FAIL（FRAME 本体改了没盖版本）"; exit 1
