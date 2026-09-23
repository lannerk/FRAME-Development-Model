#!/usr/bin/env bash
# check-links: scan every .md in the repo for relative paths to in-repo files and list the ones that resolve to nothing.
# Usage: from the repo root, bash ai/check-links.sh
#
# [Only our own navigation docs are checked] CLAUDE.md / README / the rules and indexes under ai/ / docs/ / ops/ / the product READMEs.
# **Imported prose is not checked** (ai/specs/, product/requirements/, claude-outputs/) --
# things like `ai/gateway.go` there are package paths inside the code or historical files, not repo navigation links;
# treating them as broken links is noise that buries the real ones (measured: without narrowing, only a handful of 105 were real).
# Exit 0 = everything resolves; 1 = broken links (listed as source -> target); 2 = repo root not found.
set -u
# Walk up to the repo root (the level that has CLAUDE.md); does not depend on where this script sits
ROOT="$(cd "$(dirname "$0")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/CLAUDE.md" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/CLAUDE.md" ] || { echo "cannot find the repo root (no directory with CLAUDE.md)"; exit 2; }
cd "$ROOT" || exit 2
OUT="$(mktemp)"

# Only paths starting with these top-level directories count; path characters = anything but whitespace, backticks, quotes, brackets, commas, pipes
PAT='(ai|product|docs|src|ops|dist|claude-outputs|archive|tmp)/[^[:space:]`"'"'"'()（）,，|]+\.(md|sh|py|js|css|html|json|go|txt|ps1|service)'

while IFS= read -r f; do
  # [Trap] `$PAT` starts with a top-level directory name, so a plain `grep -oE` **cuts a path out of the middle
  # of a longer name**: measured 2026-09-18, `memory-archive/type4-….md` was cut down to `archive/type4-….md`
  # and reported as a broken link that does not exist. The criterion judges a **path**, not a **substring** —
  # so require the match to start at a line start or a non-path character, then strip that character.
  grep -ohE "(^|[^A-Za-z0-9_./-])$PAT" "$f" 2>/dev/null | sed -E 's/^[^A-Za-z0-9_.-]//' | sort -u | while IFS= read -r p; do
    # skip template placeholders
    case "$p" in *'<'*|*'>'*|*'*'*|*xxx*|*XXX*|*'》'*|*'《'*|*'–'*|*'~'*|*'####'*) continue;; esac
    # Allowlist: ai/.linkcheck-ignore, one full path per line, # starts a comment
    # Two forms in the list: a **full path**, or a **prefix ending in `/`** (ignore that whole subtree).
    # 🔴 The prefix form was bought with an incident: every new `ai/template/...` reference added to
    #    `ai/roles/maintainer.md` slipped past a per-path list, and **the symptom only shows in consumer
    #    projects** (which have no template directory) -- this repo stays green forever.
    if [ -f "ai/.linkcheck-ignore" ]; then
      grep -qxF "$p" ai/.linkcheck-ignore && continue
      skip_pref=0
      while IFS= read -r ig; do
        case "$ig" in ''|'#'*) continue;; */) case "$p" in "$ig"*) skip_pref=1; break;; esac;; esac
      done < ai/.linkcheck-ignore
      [ "$skip_pref" = 1 ] && continue
    fi
    d="$(dirname "$f")"
    # A reference resolves if it exists under any of these bases:
    #  (1) the repo root (most common in docs) (2) the source root src/ (3) the directory of the referencing file
    if [ ! -e "$p" ] && [ ! -e "src/$p" ] && [ ! -e "$d/$p" ]; then
      echo "broken  $f  ->  $p"
    fi
  done
done < <(find . -name '*.md' \
          -not -path './.git/*' -not -path './tmp/*' -not -path './dist/*' \
          -not -path './archive/*' -not -path './*/archive/*' \
          -not -path './ai/specs/*' -not -path './product/requirements/*' \
          -not -path './claude-outputs/*' -not -path './src/*' \
          -not -path './_newroot/*' \
          -not -path './ai/template/*' -not -path './SYNC.md') >> "$OUT"

# ---- (2) section anchors: is the section it points at still there? ----
# [Why this exists] The Supervisor seat reported on 2026-09-15: `laws.md` pointed at `conventions.md` §9,
# while conventions.md only has sections up to 8 -- those criteria had been moved into `investigate.md` during a refactor.
# **Part (1) cannot catch that, because it only verifies file paths, not section anchors** -- another case of
# "judging the textual shadow": the file exists, so it goes green, while the thing actually being protected is
# "a reader can follow the pointer to that passage".
# How it judges: take the **longest prefix** of `§X` and shorten it step by step against the target file's headings
# (`## X, ...` / `### X ...` / `## §X ...`); any prefix that hits counts as reachable -- so a sentence that swallows
# body text into the anchor does not raise a false alarm, while `§9` (no ninth section at all) shrinks to nothing and stays red.
ANCH='§[0-9A-Za-z]+(\.[0-9A-Za-z]+)*'
while IFS= read -r f; do
  grep -onE '`[^`]+\.md` *'"$ANCH" "$f" 2>/dev/null | while IFS= read -r hit; do
    ln="${hit%%:*}"; rest="${hit#*:}"
    p=$(sed 's/^`\([^`]*\)`.*/\1/' <<< "$rest")
    a=$(grep -oE "$ANCH" <<< "$rest" | head -1 | sed 's/^§//')
    case "$p" in *'<'*|*'>'*|*'*'*|*'####'*) continue;; esac
    d="$(dirname "$f")"; t=""
    for c in "$p" "$d/$p" "src/$p"; do [ -f "$c" ] && { t="$c"; break; }; done
    if [ -z "$t" ]; then
      # only a bare filename (`reviewer.md §6`): judge it only when the name is unique in the repo
      case "$p" in */*) continue;; esac
      n=$(find ./ai ./docs ./product -name "$p" -not -path './ai/template*' 2>/dev/null)
      { [ -n "$n" ] && [ "$(wc -l <<< "$n")" -eq 1 ]; } && t="$n" || continue
    fi
    ok=0; s="$a"
    while [ -n "$s" ]; do
      if grep -qE "^#{1,6} +§?${s}([、，：:.,  ]|\$|—|--)" "$t"; then ok=1; break; fi
      s=$(sed 's/.$//' <<< "$s")
    done
    [ "$ok" -eq 1 ] || echo "broken anchor  $f:$ln  ->  $p §$a"
  done
done < <(find . -name '*.md' \
          -not -path './.git/*' -not -path './tmp/*' -not -path './dist/*' \
          -not -path './archive/*' -not -path './*/archive/*' \
          -not -path './claude-outputs/*' -not -path './src/*' -not -path './_newroot/*' \
          -not -path './ai/template/*' -not -path './SYNC.md' \
          -not -name 'maintenance-log.md') >> "$OUT"

if [ -s "$OUT" ]; then
  sort -u "$OUT"
  echo "---- $(sort -u "$OUT" | wc -l) broken links (section anchors included) ----"
  rm -f "$OUT"; exit 1
fi
rm -f "$OUT"
echo "LINKS-OK: paths and section anchors all point somewhere"
