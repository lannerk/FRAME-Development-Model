#!/usr/bin/env bash
# check-root: 仓库根有没有长出清单外的东西，以及草稿区的命名规矩有没有被守。
# 用法：bash ops/verify/check-root.sh
# 退出码 0 = 干净；1 = 有清单外的项或命名不合规；2 = 结构不对。
#
# 【为什么要这条】监督席 2026-09-16 实测：**旧草稿区名 `Claude outputs`（带空格、大写 C）复活成真目录，
# 而且已经提交进库**，十条守门没有一条出声。原因是当时所有守门都只判「脚本/文档里提到旧名字」，
# **判的是别人提到它，不是它存不存在**——又一次判文本影子。
# 同一轮开发席也报来：模板教人在仓库根建 `.ps1` 薄壳，与 `layout.md` §一 的顶层清单直接打架，
# 本项目照着长出了四个（`6212162`）。**两件事合起来说明：根目录从来没有守门。**
#
# 【判三条】
#   ① **仓库根的每一项（文件和目录）都必须在 `ai/rules/layout.md` §一 的顶层表里**——
#      判据的唯一出处是那张表（和预算表、归属表同一个规矩：不许在脚本里另抄一份）。
#   ② **旧名字不许作为真实路径存在**（不只是别写进脚本）。
#   ③ **`claude-outputs/<席>/` 下的一级条目必须以 `YYYY-MM-DD-` 开头**（`claude-outputs/README.md` 的命名规矩，
#      原来只写在文档里没人守）。豁免写在 `ops/verify/.rootcheck-allow`，一行一条，**显式豁免，不用「以后注意」**。
set -u
# 🔴 **只读的 git 调用一律不许建 index.lock**（监督席 2026-09-24 报的根因，实测过两次）：
# Cowork 本机工作区默认**没有删除权限**，而 `git status` / `git diff` 这类只读调用会顺手刷新索引、
# **建得出 `.git/index.lock` 却删不掉**——于是守门跑一次就在需求方的仓库里留一把死锁，
# 下一次提交（包括他自己在 SourceTree 里的）全被挡住。判的是「**别在别人的仓库里留锁**」，
# 不是「脚本能不能跑通」。`GIT_OPTIONAL_LOCKS=0` 让 git 跳过这类可选的锁；真正要写的 `add`/`commit`
# 照常拿它自己的锁，不受影响。
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
L="ai/rules/layout.md"
[ -f "$L" ] || { echo "找不到 $L（顶层清单在那儿）"; exit 2; }
ALLOW="ops/verify/.rootcheck-allow"
bad=0
allowed() { [ -f "$ALLOW" ] && grep -qxF -- "$1" "$ALLOW"; }
# 【为什么要跳过 git 忽略的东西】开发席 2026-09-16 报来：根目录 `Claude outputs` 是**桌面端自动落盘**的，
# 会反复长出来，不是谁手滑。守门要是照旧报红，就变成「高误报 ＋ 一键豁免」——那条路我们在模板同步上栽过一次。
# 判据改成**只管仓库里的东西**：`.gitignore` 挡掉的不算仓库内容（工具自己生成的目录归工具）；
# 但**一旦有人把它提交进来（被跟踪）就不再是 ignored**，照样报红。要保的那件事没变。
ignored() { git check-ignore -q -- "$1" 2>/dev/null; }
tracked() { git ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }
skip()    { tracked "$1" && return 1; ignored "$1"; }

# ---- ① 根白名单：从 layout.md §一 的表里读 ----
# 表行形如：| `ai/` | 放什么 | 谁写 | 入库 |  或 | `CLAUDE.md` | … |
WL=$(awk '/^## 一、顶层/{f=1} f && /^## 二/{exit} f && /^\|/ {
      line=$0; sub(/^\|[[:space:]]*/, "", line); sub(/[[:space:]]*\|.*$/, "", line);
      gsub(/`/, "", line); gsub(/\*\*/, "", line);
      n=split(line, a, /[ ，、]/);
      for (i=1;i<=n;i++) { t=a[i]; sub(/\/$/, "", t); if (t ~ /^[A-Za-z0-9_.-]+$/) print t }
    }' "$L" | LC_ALL=C sort -u)
WL="$WL
.git
.gitignore"
for e in * .[!.]*; do
  [ -e "$e" ] || continue
  name="${e%/}"
  grep -qxF -- "$name" <<< "$WL" && continue
  allowed "$name" && continue
  skip "$name" && continue
  echo "  ✗  仓库根多了一项，不在 $L §一 的清单里：$e"
  echo "     要么它不该在这儿（挪走），要么清单该改（那是改规范，归维护席，要进维护记录）"
  bad=$((bad+1))
done

# ---- ② 旧名字不许作为真实路径存在 ----
# 【和 check-paths.sh 的分工】那一条判「脚本/文档里写着旧名字」，这一条判「旧名字真的存在」。
OLD='Claude outputs|SourceCode|_transfer|_to_delete'
while IFS= read -r p; do
  [ -n "$p" ] || continue
  allowed "$p" && continue
  skip "$p" && continue
  echo "  ✗  旧结构的名字又长出来了（而且在仓库里）：$p"; bad=$((bad+1))
done < <(find . -maxdepth 3 \( -path ./.git -o -path ./archive -o -path ./tmp -o -path ./dist \) -prune -o \
          -print 2>/dev/null | sed 's#^\./##' | grep -E "(^|/)($OLD)(/|$)" | LC_ALL=C sort -u)

# ---- ③ claude-outputs 命名：一级条目必须带日期 ----
# 【不追溯】按 `ai/rules/workflow.md` §三之三：新判据不回头打旧交付。
# 判的是**这一项什么时候进的库**（git 首次加入的提交时间，不是 mtime —— mtime 在 clone 后全失效）。
SINCE="${ROOTRULES_SINCE:-2026-09-16}"
added_at() { git log --diff-filter=A --format=%cI -- "$1" 2>/dev/null | tail -1 | cut -c1-10; }
note(){ echo "  ·  $* （旧件，按 §三之三 不追溯）"; }
# 【claude-outputs 的一级目录只许是四席 + shared】`claude-outputs/README.md` 那张表就是清单。
# 2026-09-18 实测多出一个 `claude-outputs/INOS-V2/`（12 份编号章节 + README）——**东西没问题，位置不对**：
# 草稿区按席分家，才知道「谁写的、谁能改」（监督席那一份连一个字都不许别人动）。
# 报**一条**红（不是把里面 14 个文件各报一遍）：挪进某一席名下，或者维护席改 README 那张表。
for e in claude-outputs/*; do
  [ -e "$e" ] || continue
  b=$(basename "$e")
  case "$b" in developer|reviewer|supervisor|maintainer|shared|README.md|index.md) continue;; esac
  allowed "$e" && continue
  skip "$e" && continue
  echo "  ✗  claude-outputs 的一级目录只许是四席 + shared（见 claude-outputs/README.md）：多了 $e"
  echo "     挪进某一席名下（谁写的归谁），或者让维护席改那张表——**别把它留在没人负责的位置**"
  bad=$((bad+1))
done

for d in claude-outputs/*/; do
  [ -d "$d" ] || continue
  case "$d" in claude-outputs/shared/) continue;; esac   # shared/ 下是固定三个子目录，单独看
  case "$(basename "$d")" in developer|reviewer|supervisor|maintainer) ;; *) continue;; esac
  for e in "$d"*; do
    [ -e "$e" ] || continue
    b=$(basename "$e")
    case "$b" in README.md|index.md) continue;; esac
    allowed "$e" && continue
    printf '%s' "$b" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-' && continue
    # 【为什么放开「带 README 的分组目录」】判据要判「找得到、说得清」，不是判「名字里有没有日期」。
    # 2026-09-18 实测：审查/开发那边建了 `claude-outputs/INOS-V2/`（00-总纲、10-规划…12 份编号章节 + README.md），
    # **编号顺序本身是内容**，硬套日期前缀等于为了让守门绿而改 14 个文件名。
    # 所以：**一级条目是目录、且里面有 `README.md`（说清这是什么、什么时候的）就算合规**；里面的文件不再逐个判日期。
    [ -d "$e" ] && [ -f "$e/README.md" ] && continue
    a=$(added_at "$e")
    if [ -n "$a" ] && [ "$a" \< "$SINCE" ]; then note "$e 命名不带日期（$a 入库）"; continue; fi
    echo "  ✗  草稿区命名不合规（要 <日期>-<一句话>）：$e"; bad=$((bad+1))
  done
done

if [ "$bad" -gt 0 ]; then
  echo
  echo "ROOT-FAIL（$bad 处）"
  echo "  顶层清单的唯一出处是 $L §一；豁免写进 $ALLOW（一行一条，**显式豁免，不写「以后注意」**）。"
  exit 1
fi
echo "ROOT-OK（根上没有清单外的东西，旧名字没复活，草稿区命名带日期）"
