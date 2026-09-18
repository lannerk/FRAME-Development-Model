#!/usr/bin/env bash
# check-root: whether anything outside the list has grown at the repo root, and whether the scratch area's naming rule is actually guarded.
# Usage: bash ops/verify/check-root.sh
# Exit codes: 0 = clean; 1 = an item outside the list, or a name that breaks the rule; 2 = the structure is wrong.
#
# [Why this exists] Measured by the Supervisor seat on 2026-09-16: **the old scratch-area name came back as a real directory
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
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
L="ai/rules/layout.md"
[ -f "$L" ] || { echo "cannot find $L (the top-level list lives there)"; exit 2; }
ALLOW="ops/verify/.rootcheck-allow"
bad=0
allowed() { [ -f "$ALLOW" ] && grep -qxF -- "$1" "$ALLOW"; }
# [Why git-ignored things are skipped] A tool (e.g. the Claude desktop app) may keep recreating a directory at the root;
# a guard that reports it red every time becomes "high false-alarm rate plus a one-key exemption" -- we already paid for
# that lesson once on template sync. So the criterion is **only what is in the repo counts**: what `.gitignore` blocks is
# not repo content (a tool's own output belongs to the tool), **but the moment someone commits it (it becomes tracked)
# it is no longer ignored and goes red again**. The thing being protected has not changed.
ignored() { git check-ignore -q -- "$1" 2>/dev/null; }
tracked() { git ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }
skip()    { tracked "$1" && return 1; ignored "$1"; }

# ---- ① 根白名单：从 layout.md §一 的表里读 ----
# 表行形如：| `ai/` | 放什么 | 谁写 | 入库 |  或 | `CLAUDE.md` | … |
WL=$(awk '/^## 1\. Top level/{f=1} f && /^## 2\./{exit} f && /^\|/ {
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
  echo "  x  the repo root has an item that is not in the §1 list in $L: $e"
  echo "     either it does not belong here (move it), or the list should change (that is a rule change: Maintainer seat, and it goes into the maintenance log)"
  bad=$((bad+1))
done

# ---- ② 旧名字不许作为真实路径存在 ----
# 【和 check-paths.sh 的分工】那一条判「脚本/文档里写着旧名字」，这一条判「旧名字真的存在」。
OLD='Claude outputs|SourceCode|_transfer|_to_delete'
while IFS= read -r p; do
  [ -n "$p" ] || continue
  allowed "$p" && continue
  skip "$p" && continue
  echo "  x  a legacy-structure name has come back as a real path in the repo: $p"; bad=$((bad+1))
done < <(find . -maxdepth 3 \( -path ./.git -o -path ./archive -o -path ./tmp -o -path ./dist \) -prune -o \
          -print 2>/dev/null | sed 's#^\./##' | grep -E "(^|/)($OLD)(/|$)" | LC_ALL=C sort -u)

# ---- ③ claude-outputs 命名：一级条目必须带日期 ----
# 【不追溯】按 `ai/rules/workflow.md` §三之三：新判据不回头打旧交付。
# 判的是**这一项什么时候进的库**（git 首次加入的提交时间，不是 mtime —— mtime 在 clone 后全失效）。
SINCE="${ROOTRULES_SINCE:-2026-09-16}"
added_at() { git log --diff-filter=A --format=%cI -- "$1" 2>/dev/null | tail -1 | cut -c1-10; }
note(){ echo "  ·  $* (pre-existing, no retroactive effect per §3c)"; }
for d in claude-outputs/*/; do
  [ -d "$d" ] || continue
  case "$d" in claude-outputs/shared/) continue;; esac   # shared/ 下是固定三个子目录，单独看
  for e in "$d"*; do
    [ -e "$e" ] || continue
    b=$(basename "$e")
    case "$b" in README.md|index.md) continue;; esac
    allowed "$e" && continue
    printf '%s' "$b" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-' && continue
    a=$(added_at "$e")
    if [ -n "$a" ] && [ "$a" \< "$SINCE" ]; then note "$e 命名不带日期（$a 入库）"; continue; fi
    echo "  x  scratch-area name breaks the rule (it must be <date>-<one line>): $e"; bad=$((bad+1))
  done
done

if [ "$bad" -gt 0 ]; then
  echo
  echo "ROOT-FAIL ($bad)"
  echo "  The single source for the top-level list is $L §1; exemptions go in $ALLOW, one per line (**explicit exemptions, never "we will be careful next time"**)."
  exit 1
fi
echo "ROOT-OK (nothing outside the list at the root, no legacy name revived, scratch-area names carry dates)"
