#!/usr/bin/env bash
# check-filenames: 仓库里有没有**在 Windows 上建不出来**的文件名。
# 用法：bash ops/verify/check-filenames.sh
# 退出码 0 = 都合法；1 = 有非法的（列出来）；2 = 结构不对。
#
# 【为什么要这条】AI 会话多半跑在 Linux（容器或挂载盘）上，那边 `<` `>` `:` `|` `?` `*`
# 都是合法字符，建目录一点问题都没有。**而 Windows 上它们是非法的**——
# 于是仓库在 Linux 侧一切正常，需求方在 Windows 上一打开图形客户端就炸：
#
#   fatal: git rm: '…/prototype/<project>/feature/index.md': Invalid argument
#
# **真事**：模板里那个占位目录本来就叫 `<项目>`，改英文名时顺手改成了 `<project>`，
# 尖括号一路留着，直到需求方的 SourceTree 报错才发现。
# **这种坏法在 Linux 侧没有任何症状**，所以必须有一条守门盯着。
#
# 【判的是要保的那件事】判**路径字符本身**能不能在 Windows 上存在，
# 不是判「有没有人在文档里写过占位符」——文档正文里写 `<project>` 是对的，那是占位说明；
# 只有**真的建成目录或文件**才是问题。
set -u
# 🔴 **只读的 git 调用一律不许建 index.lock**（监督席 2026-09-24 报的根因，实测过两次）：
# Cowork 本机工作区默认**没有删除权限**，而 `git status` / `git diff` 这类只读调用会顺手刷新索引、
# **建得出 `.git/index.lock` 却删不掉**——于是守门跑一次就在需求方的仓库里留一把死锁，
# 下一次提交（包括他自己在 SourceTree 里的）全被挡住。判的是「**别在别人的仓库里留锁**」，
# 不是「脚本能不能跑通」。`GIT_OPTIONAL_LOCKS=0` 让 git 跳过这类可选的锁；真正要写的 `add`/`commit`
# 照常拿它自己的锁，不受影响。
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
bad=0
# 【只扫 git 看得见的文件】= 已跟踪的（工作区里还在的）＋ 未跟踪但没被 .gitignore 挡掉的（刚写的新文件正好在这里）。
# 原来用 find 走整棵树：tmp/、node_modules/、构建产物、会话留下的待删目录一起走，判据本来就把它们排除了，却占了大头——
# 实测一个仓库 2.5 万个文件里 65% 是 git 忽略的，挂载盘上一条守门就跑一分多钟，整张巡检表超过一次调用的上限。
# **被忽略的东西进不了仓库，查它是白查**；下面的排除条件照旧，只是不再先把它们走一遍。
# 已跟踪、但工作区里刚删掉的文件仍在清单里（`ls-files -d` 在挂载盘上要 39 秒，不划算）：读它什么也读不到，不影响判据。
# 不在 git 仓库里（例如初始化还没 git init）时退回 find。
# 判的是「需求方在 Windows 上拉下来会不会炸」，所以只看会进仓库的路径（文件 ＋ 它们的上级目录）。
VIS="$(mktemp)"; trap 'rm -f "$VIS"' EXIT
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  { git -c core.quotepath=false ls-files -c; git -c core.quotepath=false ls-files -o --exclude-standard; } 2>/dev/null \
    | awk -F/ '{p=""; for(i=1;i<NF;i++){p=(i==1)?$1:p"/"$i; print p}; print}' \
    | LC_ALL=C sort -u > "$VIS"
else
  find . -path ./.git -prune -o -print 2>/dev/null | sed 's|^\./||' | grep -v '^\.$' > "$VIS"
fi
list() { cat "$VIS"; }

# ① 非法字符： < > : " | ? *  （/ 和 \ 是分隔符，不在这里判）
while IFS= read -r p; do
  [ -z "$p" ] && continue
  echo "  ✗  含 Windows 非法字符：$p"
  bad=$((bad+1))
done < <(list | grep -E '[<>:"|?*]' || true)

# ② 结尾是点或空格（Windows 会静默去掉，于是两边文件名对不上）
while IFS= read -r p; do
  [ -z "$p" ] && continue
  echo "  ✗  文件名结尾是点或空格（Windows 会悄悄去掉）：$p"
  bad=$((bad+1))
done < <(list | grep -E '[ .]$' || true)

# ③ Windows 保留名（CON/PRN/AUX/NUL/COM1-9/LPT1-9，带不带扩展名都不行）
#    注意：用 awk 判，不用 grep -E —— grep -E 的 \t 不是制表符，是字母 t（这条自己踩过）
while IFS= read -r p; do
  [ -z "$p" ] && continue
  echo "  ✗  是 Windows 保留名，建不出来：$p"
  bad=$((bad+1))
done < <(list | awk -F/ '{
    n=$NF; sub(/\..*$/,"",n); n=toupper(n);
    if (n=="CON"||n=="PRN"||n=="AUX"||n=="NUL"||n ~ /^COM[1-9]$/||n ~ /^LPT[1-9]$/) print $0
  }' || true)

# ④ 只差大小写的重名（Windows 与 macOS 默认不区分大小写，两份会互相覆盖）
while IFS= read -r p; do
  [ -z "$p" ] && continue
  echo "  ✗  只差大小写的重名（Windows/macOS 上会互相覆盖）：$p"
  bad=$((bad+1))
done < <(list | awk '{ k=tolower($0); if (k in seen) { print seen[k]; print $0 } else seen[k]=$0 }' || true)

if [ "$bad" -gt 0 ]; then
  echo
  echo "FILENAMES-FAIL（$bad 处）"
  echo "  占位目录别用尖括号——用 _PROJECT_ 这种。**文档正文里写 <project> 是可以的，建成目录就不行。**"
  exit 1
fi
# 🔴 **扫到空集不许报绿**（审查席 2026-10-25 转监督席对照意见：缺依赖默认红，跳过要写明原因）。
nf=$(grep -c . "$VIS")
[ "$nf" -gt 0 ] || { echo "FILENAMES-FAIL（一个文件名都没扫到：不是干净，是没看——确认在仓库根下跑）"; exit 1; }
echo "FILENAMES-OK（扫了 $nf 个名字：没有 Windows 上建不出来的文件名）"
