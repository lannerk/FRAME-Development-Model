#!/usr/bin/env bash
# clear-to-delete: 删掉 AI 会话留在仓库里的 _to_delete/ 目录——**里面有 git 跟踪的文件就不删**。给需求方用。
# 用法（仓库里任意位置）：bash ops/scripts/clear-to-delete.sh        先列出来、问一句再删
#                         bash ops/scripts/clear-to-delete.sh -y     不问，直接删
#       Windows：双击 ops\scripts\clear-to-delete.bat（同一个判据）
#
# 【为什么要这条】AI 会话在「链接到这台电脑」的工作区里默认没有删除权限，删不掉的东西就挪进同一层的 _to_delete/，
# 等需求方自己删。这些目录散在仓库各处，一个就能有几千个文件（实测一次 5,686 个），守门每次都要走一遍。
# 【判据】_to_delete/ 里**没有一份 git 跟踪的文件**才删：挪进去的东西原本若在 git 里，
# 原位置在 git 看来是「删除」、新位置是「未跟踪」，照样删得掉；**真有被跟踪的，说明有人把它提交了，先别动**。
# 不进 node_modules/ 与 .git/ 里找（那里不会有，走一遍很慢）。
set -u
export GIT_OPTIONAL_LOCKS=0
yes=0; case "${1:-}" in -y|--yes|/y) yes=1;; esac
root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "不在 git 仓库里"; exit 2; }
cd "$root" || exit 2

list=(); kept=0
while IFS= read -r d; do
  d="${d#./}"
  if [ -n "$(git ls-files -- "$d" 2>/dev/null | head -1)" ]; then
    echo "  · 跳过（里面有 git 跟踪的文件，先在图形客户端里看一眼）：$d"; kept=$((kept+1)); continue
  fi
  list+=("$d")
done < <(find . \( -path ./.git -o -name node_modules \) -prune -o -type d -name _to_delete -print -prune 2>/dev/null)

if [ "${#list[@]}" -eq 0 ]; then echo "CLEAR-TO-DELETE-OK（没有可清的 _to_delete 目录）"; exit 0; fi
echo "下面 ${#list[@]} 个 _to_delete 目录可以删："
for d in "${list[@]}"; do echo "  $d（$(find "$d" -type f 2>/dev/null | wc -l) 个文件）"; done
if [ "$yes" != 1 ]; then
  a=""; read -r -p "确认删除？输入 y 回车：" a || true
  case "$a" in y|Y) ;; *) echo "没删。"; exit 0;; esac
fi
fail=0
for d in "${list[@]}"; do
  rm -rf -- "$d" 2>/dev/null
  if [ -e "$d" ]; then echo "  ✗ 删不掉：$d"; fail=$((fail+1)); fi
done
[ "$fail" -eq 0 ] || { echo "CLEAR-TO-DELETE-FAIL（$fail 个删不掉——多半是没有删除权限，或文件正被占用）"; exit 1; }
echo "CLEAR-TO-DELETE-OK（删了 ${#list[@]} 个目录）"
