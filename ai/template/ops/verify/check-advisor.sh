#!/usr/bin/env bash
# check-advisor：开场顾问库（ai/advisor/）守的是**两件事**，不是「文件在不在」。
# 用法：bash ops/verify/check-advisor.sh
#       ADVISOR_DIR=<拷贝> bash ops/verify/check-advisor.sh   在拷贝上造错（反向断言用）
# 退出码 0 = 过（含不适用跳过）；1 = 有问题；2 = 结构不对。
#
# 🔴 **它保的那两件事**：
#   ① **每条推荐都说得出「为什么」和「什么时候不适用」**——只写「推荐 Go」的卡片会被当成默认值照抄，
#      而顾问库的全部价值就在「为什么这样建议、不这样会怎样」。判据落在**卡片与题目自己的四段**上，
#      不是「文件里出现过『为什么』三个字」。
#   ② **一个字的私有内容都不许留在里面**——这个目录会随 FRAME 同步进**开源仓库**。
#      判据是**宿主侧的私有词清单**（`ops/verify/.private-words`，一行一个词，`#` 注释）：
#      🔴 **清单本身是 skip 类、永不分发**——把清单带进开源等于把要藏的词列出来给人看（实测过这类反效果）。
#
# 【为什么不做「文件必须齐」这条判据】顾问库是逐步长起来的，缺一份 `domains/*` 是正常状态；
# 而**把「齐不齐」判成红，只会逼人建空文件**——空文件比没有更坏（它让人以为查过了）。
set -u
# 🔴 **只读的 git 调用一律不许建 index.lock**（监督席 2026-09-24 报的根因，实测过两次）：
# Cowork 本机工作区默认**没有删除权限**，而 `git status` / `git diff` 这类只读调用会顺手刷新索引、
# **建得出 `.git/index.lock` 却删不掉**——于是守门跑一次就在需求方的仓库里留一把死锁，
# 下一次提交（包括他自己在 SourceTree 里的）全被挡住。判的是「**别在别人的仓库里留锁**」，
# 不是「脚本能不能跑通」。`GIT_OPTIONAL_LOCKS=0` 让 git 跳过这类可选的锁；真正要写的 `add`/`commit`
# 照常拿它自己的锁，不受影响。
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
D="${ADVISOR_DIR:-ai/advisor}"
WORDS="${PRIVATE_WORDS:-ops/verify/.private-words}"
PROFILE="${PROFILE_PATH:-product/requirements/requester-profile.md}"
CLASSES="${CLASSES_FILE:-ops/frame/classes.txt}"

# 不适用就跳过：没开顾问库的项目不该被一条不适用的守门拦住（和 check-randd / check-cachebust 同一条行为）
[ -d "$D" ] || { echo "ADVISOR-SKIP（没有 $D —— 这个项目没开开场顾问，跳过）"; exit 0; }

bad=0

# ── ① 选型卡四段齐 ──────────────────────────────────────────────
# 一张卡 = 一个 `### 标题`，下面必须能找到「推荐」与「为什么」；
# **「不适用」与「可反悔点」至少要有一个**——有些卡确实处处适用，但那时必须写清「可反悔点」，
# 否则读的人无法判断「照做了将来能不能改」。
if [ -f "$D/stack.md" ]; then
  awk -v RS='\n### ' 'NR>1{
      split($0, L, "\n"); title=L[1];
      hasR = ($0 ~ /推荐/); hasW = ($0 ~ /为什么/);
      hasN = ($0 ~ /不适用/) || ($0 ~ /可反悔点/);
      if (!hasR || !hasW || !hasN) {
        printf "  ✗  选型卡「%s」缺：%s%s%s\n", title,
          (hasR?"":"推荐 "), (hasW?"":"为什么 "), (hasN?"":"不适用/可反悔点");
        c++
      }
    } END{ exit (c>0?1:0) }' "$D/stack.md" || bad=$((bad+1))
fi

# ── ② 每道题都写得出「为什么问」与「推荐」 ────────────────────────
# 一道题 = 一行 `**<字母><数字> …**`（A1、B2……）。判的是**这一题自己**的四段，
# 不是整份文件里出现过这几个词（判文件＝判文本影子，一份文件只要开头写过一次就永远绿）。
if [ -f "$D/questions.md" ]; then
  python3 - "$D/questions.md" <<'PY' || bad=$((bad+1))
import re, sys
src = open(sys.argv[1], encoding='utf-8').read()
blocks = re.split(r'\n(?=\*\*[A-Z]\d+\s)', src)
missing = []
for b in blocks[1:]:
    title = b.split('\n', 1)[0].strip().strip('*')[:40]
    if '为什么问' not in b: missing.append((title, '为什么问'))
    elif '推荐' not in b:   missing.append((title, '推荐'))
for t, w in missing:
    print(f"  ✗  题目「{t}」缺「{w}」—— 没有「为什么问」的题会被跳过，没有「推荐」的题等于把选择推回给不懂技术的人")
sys.exit(1 if missing else 0)
PY
fi

# ── ③ 画像必须是 seed，且不在顾问库里 ───────────────────────────
if [ -f "$CLASSES" ]; then
  if ! grep -qE "^seed[[:space:]]+${PROFILE//\//\\/}$" "$CLASSES"; then
    echo "  ✗  $PROFILE 在 $CLASSES 里不是 seed —— 画像是项目私有内容，"
    echo "     标成 follow 会把需求方的偏好**推回开源仓库**（这条是不可逆的泄露）。"
    bad=$((bad+1))
  fi
fi
if [ -f "$D/$(basename "$PROFILE")" ]; then
  echo "  ✗  画像不该放在 $D/ 里 —— 那个目录是 follow，会被同步出去。"; bad=$((bad+1))
fi

# ── ④ 私有词那一条**搬走了** ─────────────────────────────────────
# 需求方 2026-09-26 拍板「frame 也应该和具体项目无关」之后，那一条要扫的不只是顾问库，
# 而是**整份模板与源仓库**——它已经独立成 `ops/verify/check-debrand.sh`。
# 🔴 **留在这里会让红说错话**：`gitignore.template` 里漏了一个产品名，报「开场顾问不合格」
# 只会让人去翻顾问库。**一条守门守一件事，红了要能自己说清是哪件事。**

if [ "$bad" -gt 0 ]; then
  echo
  echo "ADVISOR-FAIL（$bad 处）"
  exit 1
fi
echo "ADVISOR-OK（选型卡四段齐、每题有「为什么问」与「推荐」、画像是 seed；私有词由 check-debrand 扫）"
