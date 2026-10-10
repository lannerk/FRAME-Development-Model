#!/usr/bin/env bash
# check-ide：《模型及 Effort 指定规则》（ai/rules/model-effort.md）的守门。
# 用法：bash ops/verify/check-ide.sh
#   反向断言请在拷贝上做：IDE_CONF=<拷贝的 frame-repo.conf> IDE_DIR=<拷贝的 ai/ide> IDE_SCAN="<要扫 subagents: 的目录>" IDE_RULES="<要扫模型名的文件或目录>"
# 退出码 0 = 过；1 = 有红；2 = 结构不对。
#
# 【判什么】一直查：tier-rule= 只许 on / off；ide= 写了工具就得有那份实现文件；规矩、手册、CLAUDE.md 里没有模型名。
#   只在 tier-rule=on 时查：当前工具的实现文件 verified: yes；四档子代理文件齐、model 值是实现文件里写着的；subagents: 段只用规定的 key。
#   只提醒、不报红：实现文件 checked: 超过 90 天。
# 【为什么关着时不查标签】关着＝和没有这套规则时一样（需求方 2026-10-10 定），标签只是信息，写成什么都不该让巡检变红。
# 【为什么不在正文里查等级名】low / medium / high / max 是普通英文词，英文规矩随时会写到；它们只在 subagents: 段与子代理文件字段里管。
# 【会误伤的】fable、haiku 也是普通英文词：英文规矩里真要用这两个词（寓言、俳句），换个说法。
# 【拦不住的】规矩正文里写「用某某等级」这种话（等级名不查）；实现文件第 5 节的建议值本身对不对（那要实测，见 verified:）。
set -u
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
CONF="${IDE_CONF:-ai/frame-repo.conf}"
DIR="${IDE_DIR:-ai/ide}"
SCAN="${IDE_SCAN:-ai/tasks ai/bugs ai/RandD}"
RULES="${IDE_RULES:-CLAUDE.md ai/rules ai/roles}"
MODELS='(opus|sonnet|haiku|fable|gpt-[0-9]|gemini-[0-9]|deepseek|glm-[0-9]|qwen|kimi)'
KEYRE='^((strong|normal|light|top \(approved [0-9]{4}-[0-9]{2}-[0-9]{2}\))(, ?complex)?|complex)$'
bad=0
red(){ echo "  ✗  $*"; bad=$((bad+1)); }
get(){ [ -f "$CONF" ] && grep -E "^$1=" "$CONF" | tail -1 | cut -d= -f2- | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//'; }
hdr(){ awk 'NR==1 && /^---[[:space:]]*$/ {f=1; next} f && /^---[[:space:]]*$/ {exit} f {print}' "$1"; }
hval(){ hdr "$1" | grep -E "^$2:" | head -1 | sed "s/^$2:[[:space:]]*//; s/[[:space:]]*#.*$//; s/^\"//; s/\"$//"; }
impl_of(){ if [ -f "$DIR/$1.md" ]; then echo "$DIR/$1.md"; elif [ -f "$DIR/_spare/$1.md" ]; then echo "$DIR/_spare/$1.md"; fi; }
ide="$(get ide)"; [ -n "$ide" ] || ide=undecided
rule="$(get tier-rule)"; [ -n "$rule" ] || rule=off
case "$rule" in on|off) ;; *) red "$CONF 的 tier-rule=「$rule」只许 on 或 off"; rule=off;; esac
impl=""
if [ "$ide" != undecided ]; then
  impl="$(impl_of "$ide")"
  [ -n "$impl" ] || red "$CONF 写着 ide=$ide，但 $DIR/ 里没有 $ide.md（文件名＝工具名，见 $DIR/README.md）"
fi
while IFS= read -r l; do
  t="$(printf '%s' "${l#*=}" | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//')"
  [ -n "$(impl_of "$t")" ] || red "$CONF 的 ${l%%=*}=$t 找不到实现文件"
done < <([ -f "$CONF" ] && grep -E '^ide\.[A-Za-z]+=' "$CONF")
# ① 规矩里不许有模型名（维护记录不算：它是记录，不是规矩）
nrules=0
while IFS= read -r f; do
  nrules=$((nrules+1))
  hits=$(grep -nwiE "$MODELS" "$f" | head -3 | cut -c1-70 | paste -sd'；' -)
  [ -n "$hits" ] && red "$f 里出现了模型名（规矩只写档位 key，模型名只许出现在 $DIR/<工具>.md）：$hits"
done < <(find $RULES -type f -name '*.md' 2>/dev/null | grep -v 'maintenance-log\.md$')
[ "$nrules" -gt 0 ] || red "规矩文件一份都没扫到（$RULES）：扫描器坏了，先修它，不许先信这个绿"
# ② 开着才查的三件
nsub=0
if [ "$rule" = on ]; then
  if [ -z "$impl" ]; then
    red "tier-rule=on 但工具没定（ide=$ide）：先对维护席说 ide <工具>"
  else
    v="$(hval "$impl" verified)"
    case "$v" in yes*) ;; *) red "$impl 写着 verified: ${v:-（没写）}——开开关之前要先在项目里实测（ai/rules/model-effort.md 第六节）";; esac
    ad="$(hval "$impl" agents-dir)"
    if [ -n "$ad" ] && [ "$ad" != none ]; then
      for k in top strong normal light; do
        af="$(ls "$ad"/tier-$k.* 2>/dev/null | head -1)"
        if [ -z "$af" ]; then red "四档子代理文件缺 $ad/tier-$k.*（照 $impl 第 6 节生成，或对维护席说 ide $ide）"; continue; fi
        m="$(grep -E '^[[:space:]]*"?model"?[[:space:]]*[:=]' "$af" | head -1 | sed -E 's/^[^:=]*[:=][[:space:]]*//; s/[",]//g; s/[[:space:]]*$//')"
        [ -z "$m" ] || grep -qF "\`$m\`" "$impl" || red "$af 的 model「$m」不在 $impl 里（文件被手改过？照第 6 节重新生成）"
      done
    fi
  fi
  while IFS= read -r f; do
    nsub=$((nsub+1))
    while IFS= read -r v; do
      [ -n "$v" ] && red "$f 的 subagents: 段写着「$v」——只许 strong / normal / light（可加 , complex），top 只能写成 top (approved <日期>)"
    done < <(awk '/^subagents:[[:space:]]*$/ {s=1; next}
        s && /^- / { n=split($0, p, ":"); v=p[n]; gsub(/^[ \t]+|[ \t]+$/, "", v); print v; next }
        s {s=0}' "$f" | grep -vE "$KEYRE")
  done < <(grep -rlE '^subagents:[[:space:]]*$' $SCAN 2>/dev/null)
fi
# ③ 只提醒：实现文件多久没核
now=$(date +%s); stale=""
for f in "$DIR"/*.md "$DIR"/_spare/*.md; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README*) continue;; esac
  c="$(hval "$f" checked)"
  if [ -z "$c" ]; then red "$f 头部没写 checked:"; continue; fi
  ts=$(date -d "$c" +%s 2>/dev/null) || { red "$f 的 checked: $c 不是日期"; continue; }
  [ $(( (now - ts) / 86400 )) -gt 90 ] && stale="$stale $(basename "$f" .md)"
done
if [ "$bad" -gt 0 ]; then echo; echo "IDE-FAIL（$bad 处）"; echo "  规矩在 ai/rules/model-effort.md；各工具怎么落在 $DIR/README.md"; exit 1; fi
msg="IDE-OK（开关 $rule · 工具 $ide · 扫了 $nrules 份规矩，没有模型名"
if [ "$rule" = on ]; then msg="$msg · $nsub 份带 subagents: 的记录 key 都对"; else msg="$msg · 开关关着，标签不查"; fi
[ -n "$stale" ] && msg="$msg · ⚠ 久没核：$stale（跑 ops/scripts/ide-refresh.sh）"
echo "$msg）"
