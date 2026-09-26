#!/usr/bin/env bash
# check-links: 扫全仓库 .md 里指向仓库内文件的相对路径，列出指不到的。
# 用法：在仓库根执行   bash ai/check-links.sh
#
# 【只查我们自己写的导航文档】CLAUDE.md / README / ai/ 的规则与索引 / docs/ / ops/ / product 的 README。
# **不查搬进来的正文**（ai/specs/、product/requirements/、claude-outputs/）——
# 那些文档里的 `ai/gateway.go`、`src/global.css` 是在说代码里的包路径或历史文件，不是仓库导航链接，
# 拿它们当断链是噪音，会把真的断链埋掉（实测：不收窄范围时 105 条里只有个位数是真的）。
# 退出码 0 = 全部指得到；1 = 有断链（逐条列出 来源 -> 目标）；2 = 找不到仓库根。
set -u
# 往上找仓库根（有 CLAUDE.md 的那一层），不依赖脚本放在哪
ROOT="$(cd "$(dirname "$0")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/CLAUDE.md" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/CLAUDE.md" ] || { echo "找不到仓库根（没有 CLAUDE.md 的目录）"; exit 2; }
cd "$ROOT" || exit 2
OUT="$(mktemp)"

# 只认这几个顶级目录开头的路径；路径字符 = 除空白、反引号、引号、括号、逗号、竖线之外的一切（含中文）
PAT='(ai|product|docs|src|ops|dist|claude-outputs|archive|tmp)/[^[:space:]`"'"'"'()（）,，|]+\.(md|sh|py|js|css|html|json|go|txt|ps1|service)'

while IFS= read -r f; do
  # 【坑】`$PAT` 以顶层目录名开头，直接 `grep -oE` 会**从一个更长的名字中间截出来**：
  # 2026-09-18 实测 `memory-archive/type4-….md` 被截成 `archive/type4-….md`，报了一条不存在的断链。
  # 判的是**路径**，不是**子串**——所以要求匹配前面是行首或非路径字符，再把那个字符去掉。
  grep -ohE "(^|[^A-Za-z0-9_./-])$PAT" "$f" 2>/dev/null | sed -E 's/^[^A-Za-z0-9_.-]//' | sort -u | while IFS= read -r p; do
    # 模板占位跳过
    case "$p" in *'<'*|*'>'*|*'*'*|*xxx*|*XXX*|*'》'*|*'《'*|*'–'*|*'~'*|*'####'*) continue;; esac
    # 白名单：ai/.linkcheck-ignore，一行一条完整路径，# 开头是注释
    # 白名单两种写法：**整条路径**，或**以 `/` 结尾的前缀**（整段忽略）。
    # 🔴 前缀那种是实测换来的：`ai/roles/maintainer.md` 每加一条 `ai/template/...` 引用，
    #    逐条列的白名单就漏一条，而**症状只出现在消费项目里**（那边没有模板目录），本仓库永远是绿的。
    if [ -f "ai/.linkcheck-ignore" ]; then
      grep -qxF "$p" ai/.linkcheck-ignore && continue
      skip_pref=0
      while IFS= read -r ig; do
        case "$ig" in ''|'#'*) continue;; */) case "$p" in "$ig"*) skip_pref=1; break;; esac;; esac
      done < ai/.linkcheck-ignore
      [ "$skip_pref" = 1 ] && continue
    fi
    d="$(dirname "$f")"
    # 一个引用在这三种基准下任意一处存在就算指得到：
    #  ① 仓库根（文档里最常见）②源码根 src/（web/… internal/… 这类）③引用它的文件自己所在目录
    if [ ! -e "$p" ] && [ ! -e "src/$p" ] && [ ! -e "${LINKCHECK_SRC:-src/_}/$p" ] && [ ! -e "$d/$p" ]; then
      echo "断链  $f  ->  $p"
    fi
  done
done < <(find . -name '*.md' \
          -not -path './.git/*' -not -path './tmp/*' -not -path './dist/*' \
          -not -path './archive/*' -not -path './*/archive/*' \
          -not -path './ai/specs/*' -not -path './product/requirements/*' \
          -not -path './claude-outputs/*' -not -path './src/*' \
          -not -path './_newroot/*' \
          -not -path './ai/template/*' -not -path './ai/template-en/*' \
          -not -name 'maintenance-log.md') >> "$OUT"

# 【为什么把维护记录排除在第①段之外】它是**历史记录，不是导航**：
# 每一条都逐字引用需求方当时的原话和当时的路径，而路径会随重构改名、消失。
# 把历史里的旧路径判成断链，只会训练出「回头改历史」——那比断链本身更糟。
# （第②段的 §锚点判据本来就跳过它，同一个道理。）

# ---- ② §锚点：指到的那一节还在不在 ----
# 【为什么要这条】监督席 2026-09-15 报回：`laws.md` 指着 `conventions.md` §九，
# 而 conventions.md 的小节只到「八」——那几条判据早在重构时搬进了 `investigate.md`。
# **第①段查不出来，因为它只验文件路径、不验 §锚点**——又是一次「判文本影子」：
# 文件在，所以绿；而真正要保的那件事是「读的人能照着指针找到那段话」。
# 判法：把 `§X` 的**最长前缀**逐段缩短去对目标文件的标题（`## X、…` / `### X …` / `## §X …`），
# 任一前缀命中就算指得到——这样 `§二一处命令错误` 这种把正文吃进锚点的写法不会误报，
# 而 `§九`（根本没有第九节）缩到底也命中不了，照样报红。
ANCH='§[0-9A-Za-z一二三四五六七八九十〇之.]+'
while IFS= read -r f; do
  grep -onE '`[^`]+\.md` *'"$ANCH" "$f" 2>/dev/null | while IFS= read -r hit; do
    ln="${hit%%:*}"; rest="${hit#*:}"
    p=$(sed 's/^`\([^`]*\)`.*/\1/' <<< "$rest")
    a=$(grep -oE "$ANCH" <<< "$rest" | head -1 | sed 's/^§//')
    case "$p" in *'<'*|*'>'*|*'*'*|*'####'*) continue;; esac
    d="$(dirname "$f")"; t=""
    for c in "$p" "$d/$p" "src/$p"; do [ -f "$c" ] && { t="$c"; break; }; done
    if [ -z "$t" ]; then
      # 只写了文件名的（`reviewer.md §六` 这种）：全仓唯一同名才敢判，不唯一就不判
      case "$p" in */*) continue;; esac
      n=$(find ./ai ./docs ./product -name "$p" -not -path './ai/template*' 2>/dev/null)
      { [ -n "$n" ] && [ "$(wc -l <<< "$n")" -eq 1 ]; } && t="$n" || continue
    fi
    ok=0; s="$a"
    while [ -n "$s" ]; do
      if grep -qE "^#{1,6} +§?${s}([、，：:.,  ]|\$|—|--)" "$t"; then ok=1; break; fi
      s=$(sed 's/.$//' <<< "$s")
    done
    [ "$ok" -eq 1 ] || echo "锚点断链  $f:$ln  ->  $p §$a"
  done
done < <(find . -name '*.md' \
          -not -path './.git/*' -not -path './tmp/*' -not -path './dist/*' \
          -not -path './archive/*' -not -path './*/archive/*' \
          -not -path './claude-outputs/*' -not -path './src/*' -not -path './_newroot/*' \
          -not -path './ai/template/*' -not -path './ai/template-en/*' \
          -not -name 'maintenance-log.md') >> "$OUT"

if [ -s "$OUT" ]; then
  sort -u "$OUT"
  echo "---- 断链 $(sort -u "$OUT" | wc -l) 条（含 §锚点）----"
  rm -f "$OUT"; exit 1
fi
rm -f "$OUT"
echo "引用完整性 OK：路径和 §锚点都指得到"
