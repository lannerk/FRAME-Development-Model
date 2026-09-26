#!/usr/bin/env bash
# check-debrand：**FRAME 本体与具体项目无关。**
# 用法：bash ops/verify/check-debrand.sh
#       DEBRAND_DIRS="<目录…>" PRIVATE_WORDS=<清单> bash ops/verify/check-debrand.sh   （反向断言用）
# 退出码 0 = 干净（含「没有清单，跳过」）；1 = 有私有内容会被同步出去。
#
# 🔴 **需求方 2026-09-26 拍板**：「另外 frame 也应该和具体项目无关，这个之前如果搞错的话让维护席更新」。
# 判据写成一句可验的话：**FRAME 本体（两份模板，以及同步过去的源仓库）换一个完全无关的项目拿去用，
# 不需要改一个字。** 所以模板里不许出现宿主项目的名字、目录名、文件名前缀、内网 IP、提交号、会话路径。
#
# 【判的是什么】**宿主侧的私有词清单**（`ops/verify/.private-words`，一行一个词或正则，`#` 注释）
# 命中即红。🔴 **清单自己是 skip 类、永不同步**——把「要藏的词」列进开源仓库等于指给别人看。
#
# 【为什么不写死一份「通用坏词表」】哪些词算私有**只有宿主项目知道**（它自己的产品名、目录名、网段）。
# 写死在 FRAME 里就又把项目专属的东西塞回了 FRAME——这条守门自己会违反自己要保的那件事。
#
# 【为什么要连源仓库一起扫】真正会被别人看到的是**源仓库**，模板是同步过去的；
# 只扫本地等于「发布前没看」。源仓库路径从 `ai/frame-repo.conf` 的 `home=` 来，没有就只扫本地。
#
# 【两处例外，都写清理由】
#   · `ops/verify/.private-words` 本身——它就是那张清单。
#   · `ai/FRAME-VERSION` 与 `ops/frame/.baseline*`——这套同步机制自己写的账（`synced_with` 记的是
#     对手仓库的名字，属于溯源）。把它们算进来会让**每次同步自己报红**，而唯一的修法是删掉溯源。
set -u
# 🔴 只读的 git 调用一律不许建 index.lock（本机工作区可能没有删除权限，锁留下就挡住后面所有提交）。
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
WORDS="${PRIVATE_WORDS:-ops/verify/.private-words}"

if [ ! -f "$WORDS" ]; then
  echo "DEBRAND-SKIP（没有私有词清单 $WORDS —— 新项目正常；要用就一行一个词，它自己是 skip 类、永不分发）"
  exit 0
fi

DIRS="${DEBRAND_DIRS:-}"
if [ -z "$DIRS" ]; then
  for d in ai/template ai/template-en; do [ -d "$d" ] && DIRS="$DIRS $d"; done
  if [ -f ai/frame-repo.conf ]; then
    hp="$(sed -n 's/^home=//p' ai/frame-repo.conf | head -1)"
    [ -n "$hp" ] && [ ! -d "$hp" ] && hp="$HOME/mnt/$(basename "$(printf '%s' "$hp" | tr '\\' '/')")"
    for s in "$hp/ai" "$hp/ops"; do [ -n "$hp" ] && [ -d "$s" ] && DIRS="$DIRS $s"; done
  fi
fi
[ -n "$DIRS" ] || { echo "DEBRAND-SKIP（没有模板目录，也没有源仓库——这个项目不发行 FRAME）"; exit 0; }

hits=0
while IFS= read -r w; do
  case "$w" in ''|'#'*) continue;; esac
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$(grep -c -E -- "$w" "$f" 2>/dev/null || echo 0)
    echo "  ✗  私有内容「$w」出现在：$f（$n 处）"; hits=$((hits+1))
  done < <(grep -rlE --exclude-dir=.git -- "$w" $DIRS 2>/dev/null \
           | grep -v '/\.private-words$' | grep -v '/ai/FRAME-VERSION$' | grep -v '/ops/frame/\.baseline')
done < "$WORDS"

if [ "$hits" -gt 0 ]; then
  echo
  echo "DEBRAND-FAIL（$hits 处）"
  echo "  这些都会随同步进**开源仓库**。判据：**换一个完全无关的项目拿去用，不需要改一个字。**"
  echo "  改法：项目专属的路径进 ops/verify/paths.env（seed）；故事里的提交号、机器、文件名换成通用说法；"
  echo "  规矩背后的「为什么」留着——那才是它存在的理由。"
  exit 1
fi
echo "DEBRAND-OK（模板与源仓库里没有宿主项目的私有内容；扫了：$(echo $DIRS | tr ' ' ',')）"
