#!/usr/bin/env bash
# check-paths: 扫所有脚本，找写死的仓库内旧目录名。
# 用法：在仓库根执行   bash ops/verify/check-paths.sh
# 退出码 0 = 干净；1 = 有写死的路径（逐条列出）。
# 同时扫**写死的内网 IP**：测试机会增减、IP 会变，唯一出处是 ops/machines.json（实测仓库里 192.168.51.125
# 出现过 124 次、192.168.55.109 出现过 20 次，换一台机器要改一百多处）。
#
# 为什么要这条：上一次目录重整之后没人回头扫脚本，于是 SourceCode\aios / Backend / Frontend / dev
# 这些早就不存在的名字一直留在部署脚本里（实测 10 处）。这条守门让同样的事不会再来一遍。
set -u
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
          l="$(printf '%s' "$l" | tr -d '[:space:]')"   # 去掉空白
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
          -not -path './ai/template/*' -not -path './ai/template-en/*')

if [ "$n" -gt 0 ]; then
  echo "CHECK-PATHS-FAIL（$n 个文件写死了路径或测试机 IP）"
  echo "  路径：dot-source ops/paths.ps1，用 \$Inos / \$Dist / \$Tmp / \$Outputs，别自己拼。"
  echo "  机器：读 ops/machines.json，用 id（vm-dev / nb-test）引用，别写 IP。"
  exit 1
fi
echo "CHECK-PATHS-OK（没有写死的仓库内路径，也没有写死的测试机 IP）"
