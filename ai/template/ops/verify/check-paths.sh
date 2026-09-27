#!/usr/bin/env bash
# check-paths: 扫所有脚本，找写死的仓库内旧目录名。
# 用法：在仓库根执行   bash ops/verify/check-paths.sh
# 退出码 0 = 干净；1 = 有写死的路径（逐条列出）。
# 同时扫**写死的内网 IP**：测试机会增减、IP 会变，唯一出处是 ops/machines.json
# （实测过：同一个网段的两个地址在仓库里出现了一百多次，换一台机器就要改一百多处）。
#
# 为什么要这条：某次目录重整之后没人回头扫脚本，于是几个早就不存在的目录名一直留在部署脚本里
# （实测 10 处）。这条守门让同样的事不会再来一遍。
set -u
# 🔴 **只读的 git 调用一律不许建 index.lock**（监督席 2026-09-24 报的根因，实测过两次）：
# Cowork 本机工作区默认**没有删除权限**，而 `git status` / `git diff` 这类只读调用会顺手刷新索引、
# **建得出 `.git/index.lock` 却删不掉**——于是守门跑一次就在需求方的仓库里留一把死锁，
# 下一次提交（包括他自己在 SourceTree 里的）全被挡住。判的是「**别在别人的仓库里留锁**」，
# 不是「脚本能不能跑通」。`GIT_OPTIONAL_LOCKS=0` 让 git 跳过这类可选的锁；真正要写的 `add`/`commit`
# 照常拿它自己的锁，不受影响。
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2

# 旧目录名 + 任何绝对盘符路径；路径应当来自 ops/paths.ps1，不许各写各的
# 脚本里：旧目录名 + 绝对盘符 + 写死 IP 都不许有（它们是可执行的，写错就真的跑错）
BAD_SCRIPT='SourceCode|Claude outputs|_transfer|_to_delete|[A-Za-z]:\\projects|192\.168\.[0-9]{1,3}\.[0-9]{1,3}'
# 文档里：只管写死的测试机 IP。文档可以**叙述**历史（"以前长出六个 _to_delete"），那是记录不是配置
BAD_DOC='192\.168\.[0-9]{1,3}\.[0-9]{1,3}'

n=0
scan() {   # $1=文件 $2=正则
  hits=$(grep -nE "$2" "$1" 2>/dev/null | head -5)
  [ -z "$hits" ] && return 0
  echo "── $1"; printf '%s\n' "$hits" | sed 's/^/   /'
  n=$((n+1))
}

# 豁免清单：ops/.pathcheck-ignore，一行一条路径前缀，# 开头是注释。
# 每条都要写清「为什么豁免、什么时候去掉」——挂着任务号的临时豁免才算数，无限期的不算。
EX="$ROOT/ops/.pathcheck-ignore"
skip(){ [ -f "$EX" ] || return 1; while IFS= read -r l; do
          l="${l%%#*}"                      # 去掉行尾注释
          # 【坑】原来用 `tr -d '[:space:]'` 把**整行空白全删**，于是
          # **带空格的路径（例如 `Claude outputs/`）写进豁免清单永远匹配不上——写了等于没写**
          #（开发席 2026-09-17 实测报来，属于「判据看着有、其实不生效」那一族）。
          # 只去首尾空白，路径中间的空格必须留着。
          l="$(printf '%s' "$l" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
          [ -z "$l" ] && continue
          case "${1#./}" in $l*) return 0;; esac
        done < "$EX"; return 1; }

while IFS= read -r f; do
  skip "$f" && continue
  # 唯一出处自己豁免：paths.ps1 管路径、machines.json 管机器；迁移文档与本脚本要写清旧名字
  case "$f" in
    # 【为什么这几份要跳过】它们的职责就是**提到**这些名字：机器清单、路径变量、守门自己的判据、真机文档。
    # `check-root.sh` 2026-09-16 加入这一行——它要判「旧名字有没有复活成真路径」，**名单必须写在它自己里**，
    # 不跳过就是「守门因为守门而报红」。
    ./ops/paths.ps1|./ops/machines.json|./ops/verify/check-paths.sh|./ops/verify/check-root.sh|./docs/ops/realmachine.md|./MIGRATION.md) continue;;
    # 逐字记录区：需求方原话一个字都不许改，他嘴里说出来的 IP 也照抄。
    # 这不是配置，是历史引用——改了它就等于篡改需求记录。
    ./product/requirements/inbox.md|./product/requirements/verbatim/*) continue;;
  esac
  case "$f" in
    *.md) scan "$f" "$BAD_DOC";;
    *)    scan "$f" "$BAD_SCRIPT";;
  esac
done < <(find . \( -name '*.ps1' -o -name '*.sh' -o -name '*.service' -o -name '*.md' \) \
          -not -path './.git/*' -not -path './tmp/*' -not -path './dist/*' \
          -not -path './archive/*' -not -path './_newroot/*' \
          -not -path './ai/template/*' -not -path './ai/template-en/*' \
          | while IFS= read -r f; do
              # 【为什么要跳过 git 忽略的】裸 `find .` 连 `.gitignore` 掉的东西一起扫，
              # 于是桌面端自动落盘的 `Claude outputs/`（里面是别席正在写的稿子）被判红——
              # **守门只该管仓库里的东西**（和 `check-root.sh` 同一个判据：被跟踪的照样管）。
              git ls-files --error-unmatch -- "$f" >/dev/null 2>&1 && { echo "$f"; continue; }
              git check-ignore -q -- "$f" 2>/dev/null || echo "$f"
            done)

# ── 🔴 第三条：脚本里不许在双引号 echo 里写反引号 ──────────────────────
# 【为什么要这条】这是本项目**踩了六次**的同一个坑（项目记忆第 3 条）：写提示文案时按 markdown 习惯
# 用反引号引一个路径或参数名，而**双引号里的反引号是命令替换**——于是守门一报红就去「执行」那段文字，
# 出过「执行一份手册、递归打印 4467 行错误」「在仓库根建出 43 个 0 字节垃圾文件」这样的事故。
# **`bash -n` 查不出来**（语法完全合法），只有真跑到那一行才炸，所以它一直靠人记——而人记了六次没记住。
# 判据：**非注释行**里同时出现 echo 加双引号和反引号就报红。
# （注释里举例说明这个坑是正当的，所以跳过注释行——否则这条判据会把「写下这条判据」本身判成违规，
#  实测：第一版就把自己的说明文字报成了一处红。）
# 改法：提示文案里用「」或不加引号，真要执行命令就用 $( )。
# 【不追溯】按 ai/rules/workflow.md §三之三：新判据不回头打旧交付。
# 闸门用 **git 首次入库时间**（不是 mtime——clone 一次 mtime 就全变了）：这一天之后入库的报红，
# 之前的只提醒，并由归属席自己修（改法一行，但那是它的文件）。
BQ_SINCE="${BACKTICK_SINCE:-2026-09-27}"
nbq=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  # 🔴 转义过的反引号（\`）在双引号里是**字面量**，不是命令替换——先把它们抹掉再判，
  # 否则会把「正确的写法」判成违规（实测：src 下一份 09-15 入库的脚本就是这样一处误报）。
  # sed 不改行数，所以 grep -n 的行号仍然对得上原文件。
  hits=$(sed 's/\\`//g' "$f" | grep -nE '^[[:space:]]*[^#]*echo[[:space:]]+"[^"]*`' | cut -d: -f1)
  [ -n "$hits" ] || continue
  a=$(git log --diff-filter=A --format=%cs -1 -- "$f" 2>/dev/null)
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if [ -n "$a" ] && [ "$a" \< "$BQ_SINCE" ]; then
      echo "  ·  $f:$line 双引号 echo 里有反引号（$a 入库，按 §三之三 不追溯——归属席自己改）"
    else
      echo "  ✗  $f:$line —— 双引号 echo 里有反引号：那是命令替换，会把文案当命令跑（项目记忆第 3 条，踩过六次）"
      nbq=$((nbq+1))
    fi
  done <<< "$hits"
# 🔴 **未跟踪的新脚本也要扫**：`git ls-files` 看不见它们，而**刚写出来的错正好在那儿**
# （反向断言第一版就栽在这：造了一个未提交的脚本，守门一声不出——和 #35 给 `--dry` 补
# `--others` 是同一个坑）。所以两份清单都要：已跟踪 ＋ 未跟踪且没被 gitignore 挡掉的。
done < <( { git -c core.quotepath=false ls-files -- '*.sh'; \
            git -c core.quotepath=false ls-files --others --exclude-standard -- '*.sh'; } 2>/dev/null \
          | grep -vE '^(ai/template|ai/template-en)/' | LC_ALL=C sort -u )
if [ "$nbq" -gt 0 ]; then
  echo "CHECK-PATHS-FAIL（$nbq 处双引号 echo 里写了反引号）"
  echo "  文案里用「」或去掉引号；要执行命令用 \$( )。**bash -n 查不出这一类**，只有跑到才炸。"
  exit 1
fi

if [ "$n" -gt 0 ]; then
  echo "CHECK-PATHS-FAIL（$n 个文件写死了路径或测试机 IP）"
  echo "  路径：dot-source ops/paths.ps1，用它定义的变量（项目根 / dist / tmp / outputs），别自己拼。"
  echo "  机器：读 ops/machines.json，用 id（vm-dev / nb-test）引用，别写 IP。"
  exit 1
fi
echo "CHECK-PATHS-OK（没有写死的仓库内路径，也没有写死的测试机 IP）"
