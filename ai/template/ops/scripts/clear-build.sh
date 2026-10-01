#!/usr/bin/env bash
# clear-build: 清掉全仓库的依赖与构建产物目录（node_modules、dist……）——**只删 git 忽略的**。给需求方用。
# 用法（仓库里任意位置）：bash ops/scripts/clear-build.sh        先列出来、问一句再删
#                         bash ops/scripts/clear-build.sh -y     不问，直接删
#       Windows：双击 ops\scripts\clear-build.bat（同一个判据）
# 项目还有别的构建目录名：环境变量 CLEAR_BUILD_EXTRA="名字 名字" 追加，不用改这份（它是 FRAME 本体，同步会覆盖）。
#
# 【为什么要这条】AI 会话在仓库里装依赖、出构建产物，这些 git 不收，却会一直留着：
# 守门扫全仓库时要多走上万个文件（实测一个仓库 2.5 万个文件里 65% 是 git 忽略的），挂载盘上一次巡检因此超时。
# 而 AI 会话默认没有删除权限——所以清理交给需求方一键做。
# 【判据只有一条：git 忽略的才删】名字对上还不够，**必须 git 自己说「这是忽略的」**：
# 候选直接问 git（ls-files --others --ignored --directory），名字只是第二道筛子。
# 整个被忽略的父目录（例如 tmp/）git 只报父目录本身，里面的不会出现在候选里——tmp/ 是各席的草稿区，归各席自己清。
# 【为什么不直接 git clean -X】它删掉**所有**忽略的东西：本机配置、密钥文件、tmp/ 里别席还没合回去的稿子。
set -u
export GIT_OPTIONAL_LOCKS=0
yes=0; case "${1:-}" in -y|--yes|/y) yes=1;; esac
root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "不在 git 仓库里"; exit 2; }
cd "$root" || exit 2
names=" node_modules dist build out .next .nuxt .svelte-kit .turbo .vite .parcel-cache .cache coverage __pycache__ .pytest_cache ${CLEAR_BUILD_EXTRA:-} "

list=()
while IFS= read -r p; do
  case "$p" in */) ;; *) continue;; esac
  d="${p%/}"; b="${d##*/}"
  # 仓库根的 dist/ 不算：按 ops/ 与 dist/README.md 的约定，那里放的是安装包、升级包这类**交付物**，未必能当场重建
  [ "$d" = dist ] && continue
  case "$names" in *" $b "*) ;; *) continue;; esac
  # 兜底：真有被跟踪的文件就不碰（git 判成整目录忽略时本不该有，但删错的代价不可逆）
  [ -z "$(git ls-files -- "$d" 2>/dev/null | head -1)" ] || { echo "  · 跳过（里面有 git 跟踪的文件）：$d"; continue; }
  list+=("$d")
done < <(git -c core.quotepath=false ls-files --others --ignored --exclude-standard --directory 2>/dev/null)

if [ "${#list[@]}" -eq 0 ]; then echo "CLEAR-BUILD-OK（没有可清的构建目录）"; exit 0; fi
echo "下面 ${#list[@]} 个目录 git 不收、名字是依赖或构建产物，可以删："
for d in "${list[@]}"; do echo "  $d"; done
if [ "$yes" != 1 ]; then
  a=""; read -r -p "确认删除？输入 y 回车：" a || true
  case "$a" in y|Y) ;; *) echo "没删。"; exit 0;; esac
fi
fail=0
for d in "${list[@]}"; do
  rm -rf -- "$d" 2>/dev/null
  if [ -e "$d" ]; then echo "  ✗ 删不掉：$d"; fail=$((fail+1)); fi
done
[ "$fail" -eq 0 ] || { echo "CLEAR-BUILD-FAIL（$fail 个删不掉——多半是没有删除权限，或文件正被占用）"; exit 1; }
echo "CLEAR-BUILD-OK（删了 ${#list[@]} 个目录；要用时重新装依赖、重新构建）"
