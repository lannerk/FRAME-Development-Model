#!/usr/bin/env bash
# check-mail: 席间信箱有没有烂掉。
# 用法：bash ops/verify/check-mail.sh
#       MAIL_DIR=/tmp/mailtest bash ops/verify/check-mail.sh   ← 反向断言请指到拷贝上做
# 退出码 0 = 信箱干净；1 = 有问题；2 = 结构不对。
#
# 【为什么要这条】信箱是给「话」用的，最容易烂成两种样子：
#   ① **变成公告板**：已读的信留在里面堆着，下一个人就不再认真看（收件簿当年就是这么烂的）；
#   ② **变成第二本台账**：把派活写进信里，和 ai/tasks/ 两处不一致，谁也不知道哪边是真的。
# 所以这条守门判的是**要保的那件事**：信箱里只剩「还没人处置的话」。
#
# 【为什么是 to-<收信席>/from-<发信席>.md 这种布局】**一个发信人一份，谁都不碰别人的文件**——
# 归档拆成一席一份之后，投递口还剩最后一处共写面：三个发信人往同一份信箱尾巴上追加，
# git 会在同一个 hunk 上冲突（需求方用 Windows SourceTree，解冲突要落到他头上）。拆到这一层就归零了。
# **发信人写在文件名里，所以信里不再有「谁发的」那一栏**（同一个事实不双写）。
#
# 【判十六条】字段齐 · 路径指得到 · 不许原处标已读 · 不许躺过 7 天 · 每份不许超 12 行 ·
#   「要我做什么」不许只是一个编号（那是派活）· 不许发客套回执 ·
#   「答复」「通知」不许再要求回信（防对聊死循环）· 同一封信不许重复发 ·
#   同一发信人非通知类不许堆过 3 封（收信异常要上报）· 四席各三份投递口都得在 ·
#   归档一席一月一份、每行带处置结果（共用一份必然 git 冲突）· **归档只许增不许减** ·
#   **开发席↔审查席之间不许拿信箱谈任务/bug**（丢了台账就丢了开发追踪）·
#   这一对**类型只许「请求」「通知」、未处置最多 1 封**（需求方：它们基本上不需要互相发信）。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
D="${MAIL_DIR:-ai/mail}"
[ -d "$D" ] || { echo "找不到 $D"; exit 2; }
# 反向断言别在真信箱上造错、再用「删掉带某个词的行」收尾——**真的信会被一起删掉**，这一轮发生过一次。
STALE_DAYS="${MAIL_STALE_DAYS:-7}"
CAP="${MAIL_CAP:-12}"
FLOOD="${MAIL_FLOOD:-3}"
TYPES="建议 转告 通知 请求 答复"
SEATS="developer reviewer supervisor maintainer"
# 【R&D 线的编外座位】研究席**只和监督席通信**（`ai/roles/researcher.md`：它写只在 `ai/RandD/`，
# 要动别的目录得请监督席）。所以它**不进四席的投递口矩阵**——那会凭空多出 6 份没人用的文件，
# 而**没人用的投递口比没有更坏**：它会让人以为可以往那儿发。只认下面这一对。
RND_SEAT="${RND_SEAT:-researcher}"; RND_PEER="${RND_PEER:-supervisor}"
bad=0
today=$(date +%s)

for f in "$D"/to-*/from-*.md; do
  [ -f "$f" ] || continue
  recv=$(basename "$(dirname "$f")"); recv=${recv#to-}
  sender=$(basename "$f" .md); sender=${sender#from-}
  # 研究席的投递口只许配监督席
  if [ "$recv" = "$RND_SEAT" ] || [ "$sender" = "$RND_SEAT" ]; then
    other="$sender"; [ "$sender" = "$RND_SEAT" ] && other="$recv"
    [ "$other" = "$RND_PEER" ] || { echo "  ✗  $f —— 研究席只和监督席通信（见 ai/roles/researcher.md），这份投递口不该存在"; bad=$((bad+1)); }
  fi
  [ "$recv" = "$sender" ] && { echo "  ✗  $f —— 自己给自己发信，这份不该存在"; bad=$((bad+1)); }
  n=$(wc -l < "$f")
  [ "$n" -gt "$CAP" ] && { echo "  ✗  $f  $n 行 / 上限 $CAP —— 满了不是加大上限，是没人读或者发信太碎"; bad=$((bad+1)); }
  rows=0
  while IFS= read -r line; do
    # 只认表格数据行：必须以 | 开头。**正文和引言里也有「已读」这种词，不跳开就会被当成信解析**
    #（第一版就栽在这儿：标题和引言被解析成了三封空信，一口气报出 124 处假红）。
    case "$line" in '|'*) ;; *) continue;; esac
    case "$line" in '|---'*|'| 日期 '*|'|日期'*) continue;; esac
    stripped=$(printf '%s' "$line" | tr -d '| ')
    [ -z "$stripped" ] && continue
    IFS='|' read -r _ c1 c2 c3 c4 c5 _rest <<< "$line"
    trim() { printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }
    d=$(trim "${c1:-}"); what=$(trim "${c2:-}"); where=$(trim "${c3:-}")
    typ=$(trim "${c4:-}"); reply=$(trim "${c5:-}")
    tag="$f: $(printf '%s' "$what" | cut -c1-24)"
    rows=$((rows+1))
    # ① 五栏都不许空
    for pair in "日期:$d" "要我做什么:$what" "细节在哪:$where" "类型:$typ" "要不要回:$reply"; do
      [ -n "${pair#*:}" ] || { echo "  ✗  $tag —— 「${pair%%:*}」栏是空的（没有就写 —）"; bad=$((bad+1)); }
    done
    # ② 日期格式与超期
    if ! printf '%s' "$d" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
      echo "  ✗  $tag —— 日期「$d」不是 YYYY-MM-DD"; bad=$((bad+1))
    else
      ts=$(date -d "$d" +%s 2>/dev/null || echo "$today")
      age=$(( (today - ts) / 86400 ))
      [ "$age" -gt "$STALE_DAYS" ] && { echo "  ✗  陈信 $age 天没人处置：$tag —— 要么处置，要么发信人收回改走别的路"; bad=$((bad+1)); }
    fi
    # ③ 类型与要不要回只许是定好的值
    grep -qw -- "$typ" <<< "$TYPES" || { echo "  ✗  $tag —— 「类型」写的是「$typ」，只许是：$TYPES"; bad=$((bad+1)); }
    case "$reply" in 要|不要) ;; *) echo "  ✗  $tag —— 「要不要回」写的是「$reply」，只许「要」或「不要」"; bad=$((bad+1));; esac
    # 🔴 防对聊死循环：**「答复」和「通知」一律不许再要求回信**。
    # 判据（需求方 2026-09-15 定的）：**只有「看完冒出新问题、自己定不了、要再问一次」才回信**；
    # 照做了／自己拍了板／只是通知，**一概不回**——**归档那一行就是回执**。
    if [ "$reply" = "要" ]; then
      case "$typ" in
        答复|通知) echo "  ✗  $tag —— 类型「$typ」不许再要求回信（一来一回就到顶；还谈不完开任务/咨询单）"; bad=$((bad+1));;
      esac
    fi
    # 🔴 客套回执直接判红（需求方原话：「已收到，谢谢，你的提议很好之类的无任何作用的不需要回信」）。
    # 判据：把客套词一个个划掉，**划完什么都不剩** = 这封信没带任何要做的事。
    core=$(printf '%s' "$what" | sed 's/[`*「」 。；;：:！!?？,，.、~～（）()]//g')
    resid=$(printf '%s' "$core" | sed -e 's/已收到//g' -e 's/收到//g' -e 's/谢谢//g' -e 's/多谢//g' \
      -e 's/好的//g' -e 's/知道了//g' -e 's/明白了//g' -e 's/明白//g' -e 's/已处理//g' -e 's/处理完了//g' \
      -e 's/同意//g' -e 's/赞同//g' -e 's/认可//g' -e 's/你的//g' -e 's/提议//g' -e 's/建议//g' \
      -e 's/很好//g' -e 's/不错//g' -e 's/辛苦了//g' -e 's/辛苦//g' -e 's/[Oo][Kk]//g' -e 's/[Tt]hanks//g')
    if [ -z "$resid" ]; then
      echo "  ✗  $tag —— 客套回执不算信（收到／谢谢／很好这类）：不带要做的事就别发，归档行才是回执"; bad=$((bad+1))
    fi
    # 🔴 开发席 ↔ 审查席之间，**提到 T-####／B-#### 的信一律报红**。
    # 需求方 2026-09-15 原话：「开发中的问题和反馈、工作，尤其是开发和审查者，**绝大部分情况不是通过发信的**，
    # 而是用之前的项目约定记录方式来处理任务，**否则就会丢失开发追踪信息**」。
    # 判据：这两席之间的话只要挂着某条任务或 bug，**它就属于那个文件**——写进信箱等于把开发追踪从台账里抽走。
    if { [ "$recv" = developer ] && [ "$sender" = reviewer ]; } || { [ "$recv" = reviewer ] && [ "$sender" = developer ]; }; then
      if printf '%s %s' "$what" "$where" | grep -qE '\b(T|B)-[0-9]{4}\b'; then
        echo "  ✗  $tag —— 开发席↔审查席之间**不许拿信箱谈任务/bug**：这条挂着 $(printf '%s %s' "$what" "$where" | grep -oE '\b(T|B)-[0-9]{4}\b' | sort -u | paste -sd' ' -)，写进那个任务/bug 文件里去（丢了台账就丢了开发追踪）"; bad=$((bad+1))
      fi
    fi
    # ④ 「要我做什么」不许只是一个编号（那是派活，该在 ai/tasks/ 或 ai/bugs/）
    idonly=$(printf '%s' "$what" | tr -d '`*《》「」 ')
    if printf '%s' "$idonly" | grep -qE '^(T|B|AD|M)-[0-9]+$'; then
      echo "  ✗  $tag —— 「要我做什么」只写了一个编号＝在用信箱派活；活走台账，信传话"; bad=$((bad+1))
    fi
    # ⑤ 细节路径要指得到（多份用空格或 · 分隔；— 表示没有）
    if [ "$where" != "—" ] && [ "$where" != "-" ]; then
      # 【为什么不用 tr】`tr` 按**字节**替换，中文分隔符（·、，）是多字节，
      # 它会把中文文件名当中的字节也一起换掉，**把路径截断成一个不存在的名字，报出假红**
      #（监督席 2026-09-15 实测报来：`2026-09-15-信箱迁移丢失已处置归档.md` 被截成 `…-信箱`）。**用 sed 按字符换。**
      for pth in $(printf '%s' "$where" | sed 's/[`·、,，]/ /g' | grep -oE '[A-Za-z0-9_./-]+/[^[:space:]]+' || true); do
        # 【判文件在不在，不判后面挂了什么】信里常写 `ai/rules/laws.md:33` 指到行——
        # 要保的那件事是**那个文件还在不在**，行号不是路径的一部分。不去掉的话这种写法一律假红，
        # 而假红的唯一修法是把行号删掉＝**让规矩逼着人写得更含糊**。
        pth="${pth%%:*}"
        [ -z "$pth" ] && continue
        [ -e "$pth" ] || { echo "  ✗  $tag —— 细节路径指不到：$pth"; bad=$((bad+1)); }
      done
    fi
    # ⑥ 不许在原处标已读
    case "$line" in *已读*|*'~~'*) echo "  ✗  $tag —— 信箱里不许标已读／划掉，处置完要移进 archive/"; bad=$((bad+1));; esac
  done < "$f"

  # 🔴 ⑦ 同一封信重复发（同一句「要我做什么」在这一份里出现两次以上）
  # 需求方 2026-09-15：「相同信息未读，有阻止发信的机制」。典型是维护席连改三轮规范、发了三条「重载规范」——
  # 收信人只会执行一次，剩下两条纯占开场行数。**要补充就改那封信（或改它指向的细节文件），不要再发一封。**
  dup=$(awk -F'|' '/^\|/ {
      if ($0 ~ /^\|---/) next; if ($0 ~ /^\| *日期 /) next;
      what=$3; gsub(/^[ \t]+|[ \t]+$/, "", what); if (what == "") next; c[what]++
    } END { for (k in c) if (c[k] > 1) print c[k] " × " k }' "$f")
  if [ -n "$dup" ]; then
    while IFS= read -r line; do
      echo "  ✗  $f —— 同一封信发了多次：$line（要补充就改那封，别再发一封）"; bad=$((bad+1))
    done <<< "$dup"
  fi

  # 🔴 ⑦之二 开发席 ↔ 审查席：**这一对几乎没有发信的场景**
  # 需求方 2026-09-15 原话：「审查和开发两者**基本上无互相发信的需要，场景很少**」。
  # 所以这两份投递口另加两条更严的：**类型只许「请求」或「通知」**（建议/转告/答复都说明在谈任务），
  # **未处置最多 1 封**（第 2 封就说明在拿信箱当开发通道）。能发的例子见 ai/mail/README.md 那张对照表。
  if { [ "$recv" = developer ] && [ "$sender" = reviewer ]; } || { [ "$recv" = reviewer ] && [ "$sender" = developer ]; }; then
    badtyp=$(awk -F'|' '/^\|/ {
        if ($0 ~ /^\|---/) next; if ($0 ~ /^\| *日期 /) next;
        what=$3; typ=$5; gsub(/^[ \t]+|[ \t]+$/, "", what); gsub(/^[ \t]+|[ \t]+$/, "", typ);
        if (what == "") next;
        if (typ != "请求" && typ != "通知") print typ " ← " substr(what,1,24)
      }' "$f")
    if [ -n "$badtyp" ]; then
      while IFS= read -r line; do
        echo "  ✗  $f —— 这两席之间只许「请求」或「通知」，这封是「$line」：谈任务/方案/结论一律写进 T-####／B-####"; bad=$((bad+1))
      done <<< "$badtyp"
    fi
    if [ "$rows" -gt 1 ]; then
      echo "  ✗  $f —— 这两席之间未处置 $rows 封（上限 1）：**它们基本上不需要互相发信**，剩下的写进任务/bug 文件"; bad=$((bad+1))
    fi
  fi

  # 🔴 ⑧ 堆积：这一份里非通知类超过 MAIL_FLOOD 封没处置 = 收信异常，要上报
  # 需求方 2026-09-15：「当角色发现收信异常（过多连续同一个角色非通知的信息），查信后要通知需求方或者发信人」。
  # 堆到这个数，问题通常不在收信人手慢，而在**发信人把信箱当了工单系统**——该换轨了。
  non=$(awk -F'|' -v n=0 '/^\|/ {
      if ($0 ~ /^\|---/) next; if ($0 ~ /^\| *日期 /) next;
      what=$3; typ=$5; gsub(/^[ \t]+|[ \t]+$/, "", what); gsub(/^[ \t]+|[ \t]+$/, "", typ);
      if (what == "") next; if (typ == "通知") next; n++
    } END { print n+0 }' "$f")
  if [ "$non" -gt "$FLOOD" ]; then
    echo "  ✗  $f —— 收信异常：$sender 堆了 $non 封非通知的信（上限 $FLOOD）；要么当轮处置掉，要么告诉需求方和发信人「别再往这儿发，换任务或咨询单」"; bad=$((bad+1))
  fi
done

# 🔴 ⑨之二 归档只许增不许减（监督席 2026-09-15 提的，因为它的两行归档真的被删过一次）
# 归档文件开头就写着「只追加，不删行」，而**在这条之前没有任何东西在守那句话**。
# 判法：和上一个 commit 里的同一份比数据行数，**少了就红**。新建的文件（HEAD 里没有）跳过。
if [ -z "${MAIL_DIR:-}" ] && git rev-parse --git-dir >/dev/null 2>&1; then
  for f in "$D"/archive/*.md; do
    [ -f "$f" ] || continue
    ncur=$(grep -cE '^\| 2[0-9]{3}-' "$f" || true)
    if git cat-file -e "HEAD:$f" 2>/dev/null; then
      nold=$(git show "HEAD:$f" 2>/dev/null | grep -cE '^\| 2[0-9]{3}-' || true)
      if [ "$ncur" -lt "$nold" ]; then
        echo "  ✗  $f —— 归档行数变少了（HEAD $nold → 现在 $ncur）：归档只许增不许减，先把丢掉的行找回来（git show HEAD:$f）"; bad=$((bad+1))
      fi
    fi
  done
  # 记过账的归档文件整份消失也要报（改名/删除都算）
  while IFS= read -r g; do
    [ -e "$g" ] || { echo "  ✗  $g —— 这份归档在 HEAD 里有、现在没了：迁移/改名/删除之前先「wc -l」看内容，有数据行就先搬内容再删壳"; bad=$((bad+1)); }
  done < <(git ls-tree -r --name-only HEAD -- "$D/archive" 2>/dev/null | grep '\.md$' || true)
fi

# ⑨ 归档：文件名必须「一席一月一份」，每行必须写处置结果
# 【为什么要管文件名】共用一份归档 = 四席往同一个文件尾巴上追加，**git 冲突是必然的**（需求方 2026-09-15 指出）。
# **归档归收信人**：维护席发给监督席的信，监督席处置完归进 `supervisor-<年月>.md`——**信发给谁就属于谁**。
for f in "$D"/archive/*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  if ! printf '%s' "$bn" | grep -qE "^(developer|reviewer|supervisor|maintainer|$RND_SEAT)-[0-9]{4}-[0-9]{2}\.md$"; then
    echo "  ✗  $f —— 归档文件名要「一席一月一份」：<席>-<YYYY-MM>.md（共用一份必然 git 冲突）"; bad=$((bad+1))
  fi
  while IFS= read -r line; do
    case "$line" in '|'*) ;; *) continue;; esac
    case "$line" in '|---'*|'| 日期 '*) continue;; esac
    stripped=$(printf '%s' "$line" | tr -d '| ')
    [ -z "$stripped" ] && continue
    res=$(printf '%s' "$line" | awk -F'|' '{print $(NF-1)}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -n "$res" ] || { echo "  ✗  $f —— 归档行没写处置结果（照做 / 转成 T-#### / 拒收：理由）"; bad=$((bad+1)); }
  done < "$f"
done

# ⑩ 四席各三份投递口都得在（少一份 = 那一对之间递不进信）
for r in $SEATS; do
  for s in $SEATS; do
    [ "$r" = "$s" ] && continue
    [ -f "$D/to-$r/from-$s.md" ] || { echo "  ✗  缺 $D/to-$r/from-$s.md —— $s 递不进信给 $r"; bad=$((bad+1)); }
  done
done

# ⑪ 研究席↔监督席那一对投递口也得在（R&D 线用它，见 ai/rules/layout.md §二 RandD/）
for pair in "to-$RND_SEAT/from-$RND_PEER.md" "to-$RND_PEER/from-$RND_SEAT.md"; do
  [ -f "$D/$pair" ] || { echo "  ✗  缺 $D/$pair —— 研究席与监督席之间递不进信"; bad=$((bad+1)); }
done

if [ "$bad" -gt 0 ]; then
  echo
  echo "MAIL-FAIL（$bad 处）"
  echo "  规矩在 $D/README.md：只放未读 · 处置完移进 archive/<收信席>-<年月>.md · 信传话台账传活。"
  exit 1
fi
echo "MAIL-OK（未处置 $(cat "$D"/to-*/from-*.md 2>/dev/null | grep -cE '^\| 2[0-9]{3}-' || true) 封，都在期内）"
