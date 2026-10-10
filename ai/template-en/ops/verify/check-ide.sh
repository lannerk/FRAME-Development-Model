#!/usr/bin/env bash
# check-ide: the guard for the model and effort assignment rules (ai/rules/model-effort.md).
# Usage: bash ops/verify/check-ide.sh
#   Run reverse assertions on a copy: IDE_CONF=<copy of frame-repo.conf> IDE_DIR=<copy of ai/ide> IDE_SCAN="<dirs to scan for subagents:>" IDE_RULES="<files or dirs to scan for model names>"
# Exit 0 = pass; 1 = red; 2 = structure is wrong.
#
# [What it checks] Always: tier-rule= is on / off only; a tool named in ide= has its implementation file; no model names in the rules, handbooks or CLAUDE.md.
#   Only when tier-rule=on: the current tool's implementation file says verified: yes; the four tier files exist and their model values appear in the implementation file; subagents: blocks use only the allowed keys.
#   A reminder, never red: an implementation file whose checked: is more than 90 days old.
# [Why labels are not checked while off] Off = exactly as if these rules did not exist (Requester, 2026-10-10); labels are information and must never turn the sweep red.
# [Why level names are not checked in prose] low / medium / high / max are ordinary English words that rules will keep using; they are policed only in subagents: blocks and subagent-file fields.
# [False positives] fable and haiku are also ordinary English words: if a rule really needs them, word it differently.
# [What it cannot catch] prose like "use such-and-such level" (level names are not checked); whether section 5's suggested values are right (that takes a test, see verified:).
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
case "$rule" in on|off) ;; *) red "$CONF: tier-rule=\"$rule\" must be on or off"; rule=off;; esac
impl=""
if [ "$ide" != undecided ]; then
  impl="$(impl_of "$ide")"
  [ -n "$impl" ] || red "$CONF says ide=$ide but $DIR/ has no $ide.md (file name = tool name, see $DIR/README.md)"
fi
while IFS= read -r l; do
  t="$(printf '%s' "${l#*=}" | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//')"
  [ -n "$(impl_of "$t")" ] || red "$CONF: ${l%%=*}=$t has no implementation file"
done < <([ -f "$CONF" ] && grep -E '^ide\.[A-Za-z]+=' "$CONF")
# (1) no model names in the rules (the maintenance log is a record, not a rule)
nrules=0
while IFS= read -r f; do
  nrules=$((nrules+1))
  hits=$(grep -nwiE "$MODELS" "$f" | head -3 | cut -c1-70 | paste -sd';' -)
  [ -n "$hits" ] && red "$f names a model (rules carry tier keys only; model names belong in $DIR/<tool>.md): $hits"
done < <(find $RULES -type f -name '*.md' 2>/dev/null | grep -v 'maintenance-log\.md$')
[ "$nrules" -gt 0 ] || red "no rule files were scanned ($RULES): the scanner is broken -- fix it before trusting a green"
# (2) three checks that apply only when on
nsub=0
if [ "$rule" = on ]; then
  if [ -z "$impl" ]; then
    red "tier-rule=on but no tool is set (ide=$ide): tell the Maintainer ide <tool> first"
  else
    v="$(hval "$impl" verified)"
    case "$v" in yes*) ;; *) red "$impl says verified: ${v:-(missing)} -- test it in the project before switching on (ai/rules/model-effort.md section 6)";; esac
    ad="$(hval "$impl" agents-dir)"
    if [ -n "$ad" ] && [ "$ad" != none ]; then
      for k in top strong normal light; do
        af="$(ls "$ad"/tier-$k.* 2>/dev/null | head -1)"
        if [ -z "$af" ]; then red "tier file missing: $ad/tier-$k.* (generate it from section 6 of $impl, or tell the Maintainer ide $ide)"; continue; fi
        m="$(grep -E '^[[:space:]]*"?model"?[[:space:]]*[:=]' "$af" | head -1 | sed -E 's/^[^:=]*[:=][[:space:]]*//; s/[",]//g; s/[[:space:]]*$//')"
        [ -z "$m" ] || grep -qF "\`$m\`" "$impl" || red "$af: model \"$m\" does not appear in $impl (edited by hand? regenerate it from section 6)"
      done
    fi
  fi
  while IFS= read -r f; do
    nsub=$((nsub+1))
    while IFS= read -r v; do
      [ -n "$v" ] && red "$f: the subagents: block says \"$v\" -- only strong / normal / light (optionally , complex); top only as top (approved <date>)"
    done < <(awk '/^subagents:[[:space:]]*$/ {s=1; next}
        s && /^- / { n=split($0, p, ":"); v=p[n]; gsub(/^[ \t]+|[ \t]+$/, "", v); print v; next }
        s {s=0}' "$f" | grep -vE "$KEYRE")
  done < <(grep -rlE '^subagents:[[:space:]]*$' $SCAN 2>/dev/null)
fi
# (3) reminder only: how long since each implementation file was checked
now=$(date +%s); stale=""
for f in "$DIR"/*.md "$DIR"/_spare/*.md; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README*) continue;; esac
  c="$(hval "$f" checked)"
  if [ -z "$c" ]; then red "$f: no checked: in the header"; continue; fi
  ts=$(date -d "$c" +%s 2>/dev/null) || { red "$f: checked: $c is not a date"; continue; }
  [ $(( (now - ts) / 86400 )) -gt 90 ] && stale="$stale $(basename "$f" .md)"
done
if [ "$bad" -gt 0 ]; then echo; echo "IDE-FAIL ($bad)"; echo "  The rules are in ai/rules/model-effort.md; each tool's mapping in $DIR/README.md"; exit 1; fi
msg="IDE-OK (switch $rule . tool $ide . $nrules rule files scanned, no model names"
if [ "$rule" = on ]; then msg="$msg . $nsub records with subagents: blocks, all keys valid"; else msg="$msg . switch off, labels not checked"; fi
[ -n "$stale" ] && msg="$msg . stale:$stale (run ops/scripts/ide-refresh.sh)"
echo "$msg)"
