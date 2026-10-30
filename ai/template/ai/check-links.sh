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
# 【只扫 git 看得见的文件】= 已跟踪的（工作区里还在的）＋ 未跟踪但没被 .gitignore 挡掉的（刚写的新文件正好在这里）。
# 原来用 find 走整棵树：tmp/、node_modules/、构建产物、会话留下的待删目录一起走，判据本来就把它们排除了，却占了大头——
# 实测一个仓库 2.5 万个文件里 65% 是 git 忽略的，挂载盘上一条守门就跑一分多钟，整张巡检表超过一次调用的上限。
# **被忽略的东西进不了仓库，查它是白查**；下面的排除条件照旧，只是不再先把它们走一遍。
# 已跟踪、但工作区里刚删掉的文件仍在清单里（`ls-files -d` 在挂载盘上要 39 秒，不划算）：读它什么也读不到，不影响判据。
# 不在 git 仓库里（例如初始化还没 git init）时退回 find。
export GIT_OPTIONAL_LOCKS=0
VIS="$(mktemp)"; trap 'rm -f "$VIS"' EXIT
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  { git -c core.quotepath=false ls-files -c; git -c core.quotepath=false ls-files -o --exclude-standard; } 2>/dev/null \
    | LC_ALL=C sort -u | sed 's|^|./|' > "$VIS"
else
  find . \( -path ./.git -o -name node_modules \) -prune -o -type f -print 2>/dev/null > "$VIS"
fi
OUT="$(mktemp)"
PLANNED="$(mktemp)"
# 🔴 **已登记的外部项目投递口不扫**（2026-10-30 实测）：`ai/mail/to-*/from-<外部项目>.md` 里的路径是**对方仓库**的，
#    在本仓库必然指不到，判红只会逼人改别人写进来的信。名单与信箱守门同一处：`ops/verify/paths.env` 的 `MAIL_EXT=`。
EXT_MAIL=""; MAIL_EXT=""; [ -f ops/verify/paths.env ] && . ops/verify/paths.env
for e in $MAIL_EXT; do EXT_MAIL="$EXT_MAIL|/from-$e\.md\$"; done

# 只认这几个顶级目录开头的路径；路径字符 = 除空白、反引号、引号、括号、逗号、竖线之外的一切（含中文）
# 【坑】扩展名白名单必须**长扩展名在前**、且把 `.jsx` 列进去：这个正则**不带词尾锚**，
#   2026-10-20 实测 `…/App.jsx` 会被 `js` 匹配成 `…/App.js`（那文件不存在）→ 报断链假红。
PAT='(ai|product|docs|src|ops|dist|claude-outputs|archive|tmp)/[^[:space:]`"'"'"'()（）,，|]+\.(md|sh|py|jsx|js|css|html|json|go|txt|ps1|service)'

while IFS= read -r f; do
  # 【坑】`$PAT` 以顶层目录名开头，直接 `grep -oE` 会**从一个更长的名字中间截出来**：
  # 2026-09-18 实测 `memory-archive/type4-….md` 被截成 `archive/type4-….md`，报了一条不存在的断链。
  # 判的是**路径**，不是**子串**——所以要求匹配前面是行首或非路径字符，再把那个字符去掉。
  grep -ohE "(^|[^A-Za-z0-9_./-])$PAT" "$f" 2>/dev/null | sed -E 's/^[^A-Za-z0-9_.-]//' | sort -u | while IFS= read -r p; do
    # 模板占位跳过
    case "$p" in *'<'*|*'>'*|*'*'*|*xxx*|*XXX*|*'》'*|*'《'*|*'–'*|*'~'*|*'####'*|*_PROJECT_*) continue;; esac
    # 🔴 tmp/ 与 dist/ **按定义永不入库**（.gitignore 总规矩第 1 条）：指向它们的路径只在**某一台机器的磁盘上**存在与否，
    #    查它等于查「这次会话的磁盘」，不是查仓库。2026-10-12 实测：初始化那一轮磁盘上还留着模板带来的
    #    tmp/README.md，所以全绿；需求方一重新 clone 就红一条（`docs/guide/project-init.md` 第 4 步第 1 条提到它）。
    case "$p" in tmp/*|dist/*) continue;; esac
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
      # 🔴 目标被 .gitignore 挡掉 = **它进不了仓库**，干净克隆里必然不存在：查它是白查，不是断链。
      #    实例：一个项目把需求方画像列进了 `.gitignore`（它那边定的不入库），初始化指南里指向画像的那句在干净克隆里就报断链。
      #    只对「本机也不存在」的目标多跑一次 git（调用很少，不拖慢巡检）。
      git check-ignore -q -- "$p" 2>/dev/null && continue
      # 🔴 **标了「（待建）」的不算断链**（监督席 2026-10-27：文档里写了计划中、还没建的脚本路径，被判断链，只能改措辞绕过去）。
      #    写法：路径后面紧跟 `（待建）` 或 `(planned)`。不判红，但末尾列出来——**防止永远不建**。
      planned=0
      for suf in '`（待建）' '（待建）' '` （待建）' '` (planned)' ' (planned)'; do grep -qF -- "$p$suf" "$f" 2>/dev/null && { planned=1; break; }; done
      [ "$planned" = 1 ] && { echo "待建  $f  ->  $p" >> "$PLANNED"; continue; }
      echo "断链  $f  ->  $p"
    fi
  done
done < <(grep -E '\.md$' "$VIS" | grep -vE '^\./\.git/.*$|^\./tmp/.*$|^\./dist/.*$|^.*/node_modules/.*$|^\./archive/.*$|^\./.*/archive/.*$|^\./ai/specs/.*$|^\./product/requirements/.*$|^\./claude-outputs/.*$|^\./src/.*$|^\./_newroot/.*$|^\./ai/template/.*$|^\./ai/template-en/.*$|(^|/)maintenance\-log\.md$'"$EXT_MAIL") >> "$OUT"

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
    case "$p" in *'<'*|*'>'*|*'*'*|*'####'*|*_PROJECT_*) continue;; esac
    d="$(dirname "$f")"; t=""
    for c in "$p" "$d/$p" "src/$p"; do [ -f "$c" ] && { t="$c"; break; }; done
    if [ -z "$t" ]; then
      # 只写了文件名的（`reviewer.md §六` 这种）：全仓唯一同名才敢判，不唯一就不判
      case "$p" in */*) continue;; esac
      n=$(awk -v n="$p" -F/ '$NF==n && $0 ~ /^\.\/(ai|docs|product)\// && $0 !~ /^\.\/ai\/template/' "$VIS")
      { [ -n "$n" ] && [ "$(wc -l <<< "$n")" -eq 1 ] && [ -f "$n" ]; } && t="$n" || continue
    fi
    ok=0; s="$a"
    while [ -n "$s" ]; do
      if grep -qE "^#{1,6} +§?${s}([、，：:.,  ]|\$|—|--)" "$t"; then ok=1; break; fi
      s=$(sed 's/.$//' <<< "$s")
    done
    [ "$ok" -eq 1 ] || echo "锚点断链  $f:$ln  ->  $p §$a"
  done
done < <(grep -E '\.md$' "$VIS" | grep -vE '^\./\.git/.*$|^\./tmp/.*$|^\./dist/.*$|^.*/node_modules/.*$|^\./archive/.*$|^\./.*/archive/.*$|^\./claude-outputs/.*$|^\./src/.*$|^\./_newroot/.*$|^\./ai/template/.*$|^\./ai/template-en/.*$|(^|/)maintenance\-log\.md$'"$EXT_MAIL") >> "$OUT"

if [ -s "$PLANNED" ]; then
  echo "  （标了待建、没判断链的 $(sort -u "$PLANNED" | wc -l) 条——建好就把「（待建）」删掉：）"; sort -u "$PLANNED" | sed 's/^/    /'
fi
rm -f "$PLANNED"
if [ -s "$OUT" ]; then
  sort -u "$OUT"
  echo "---- 断链 $(sort -u "$OUT" | wc -l) 条（含 §锚点）----"
  rm -f "$OUT"; exit 1
fi
rm -f "$OUT"
echo "引用完整性 OK：路径和 §锚点都指得到"
