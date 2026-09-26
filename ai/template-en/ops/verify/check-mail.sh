#!/usr/bin/env bash
# check-mail: whether the seat mail has rotted.
# Usage: bash ops/verify/check-mail.sh
#        MAIL_DIR=/tmp/mailtest bash ops/verify/check-mail.sh   <- point reverse assertions at a copy
# Exit codes: 0 = the mail is clean; 1 = something is wrong; 2 = the structure is wrong.
#
# [Why this exists] The mail carries words, and it rots in two ways:
#   (1) **it becomes a notice board**: handled letters stay in it and pile up, and the next person stops reading carefully
#       (that is exactly how the inbox rotted once);
#   (2) **it becomes a second ledger**: work gets handed out in letters, disagrees with ai/tasks/, and nobody knows which side is true.
# So what this guard judges is **the thing being protected**: the mailbox holds nothing but words nobody has handled yet.
#
# [Why the layout is to-<recipient>/from-<sender>.md] **One file per sender, nobody touches anyone else's.**
# Once the archive was split per seat, the drop-box was the last shared write surface: three senders appending to the end
# of one file means git conflicts in the same hunk (the Requester works in Windows SourceTree, so resolving them lands on him).
# Splitting to this level takes that to zero. **The sender is in the filename, so a letter no longer carries a "From" column.**
#
# [Twelve criteria] fields filled . paths resolve . never marked read in place . never left 7 days . never over 12 lines per file .
#   "what I have to do" is never just an ID (that is handing out work) . no courtesy receipts .
#   a "reply" or a "notice" never asks for a reply (no chat loops) . the same letter is never sent twice .
#   one sender never piles up more than 3 non-notice letters (an abnormal inbox gets reported) .
#   all three drop-boxes exist for each of the four seats .
#   the archive is one file per seat per month and every row states the outcome (one shared file guarantees git conflicts).
set -u
# 🔴 **A read-only git call must never create an index.lock** (root cause reported by the Supervisor
# 2026-09-24, hit twice for real): the local Cowork workspace has **no delete permission by default**,
# while `git status` / `git diff` refresh the index as a side effect and **can create `.git/index.lock`
# without being able to remove it** -- so one guard run leaves a deadlock in the Requester's repository
# and every later commit (including his own in SourceTree) is blocked. The test is **"leave no lock in
# someone else's repo"**, not "does the script run". `GIT_OPTIONAL_LOCKS=0` makes git skip those optional
# locks; a real `add`/`commit` still takes its own lock and is unaffected.
export GIT_OPTIONAL_LOCKS=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
D="${MAIL_DIR:-ai/mail}"
[ -d "$D" ] || { echo "cannot find $D"; exit 2; }
# Do not break the real mailbox on purpose and then clean up by "deleting rows containing some word" --
# **real letters go with it**; that happened once in this very round.
STALE_DAYS="${MAIL_STALE_DAYS:-7}"
CAP="${MAIL_CAP:-12}"
FLOOD="${MAIL_FLOOD:-3}"
TYPES="suggestion hand-over notice request reply"
SEATS="developer reviewer supervisor maintainer"
# [The extra seat on the R&D line] The Researcher exchanges letters **only with the Supervisor and the
# Reviewer** (`ai/roles/researcher.md`: it writes only under `ai/RandD/`, and anything else goes through
# the Supervisor). So it **stays out of the four-seat drop-box matrix** -- wiring it to everyone would
# conjure up files nobody uses, and **a drop-box nobody uses is worse than none**: it makes people think
# they may post there. Only the pairs below are recognized.
# 🔴 **The Reviewer pair was added by the Requester's ruling of 2026-09-25** ("the researcher and the
# supervisor and the reviewer may all exchange letters; sometimes in-project research needs it").
# It came out of a measured case: the Reviewer asked the Supervisor to pass material to the Researcher;
# the Supervisor relayed it 8.5 hours later and both letters said "just pass it on" -- **pure forwarding,
# zero verification** -- while the Researcher had already read it itself (it may read the whole repo).
# **That checkpoint was already covered by the Reviewer's own duty to verify**; all it added was delay.
# 🔴 **Still closed**: Researcher -> Developer (development only takes work from the Reviewer; that split
# is not routed around) and Researcher -> Maintainer (the Maintainer only owns the rules).
# **Opening a channel is not opening write access**: writing `ai/memory.md` or touching anything outside
# `ai/RandD/` still goes through the Supervisor.
RND_SEAT="${RND_SEAT:-researcher}"; RND_PEERS="${RND_PEERS:-supervisor reviewer}"
bad=0
today=$(date +%s)

for f in "$D"/to-*/from-*.md; do
  [ -f "$f" ] || continue
  recv=$(basename "$(dirname "$f")"); recv=${recv#to-}
  sender=$(basename "$f" .md); sender=${sender#from-}
  # the Researcher's drop-boxes may only pair with the peers listed above
  if [ "$recv" = "$RND_SEAT" ] || [ "$sender" = "$RND_SEAT" ]; then
    other="$sender"; [ "$sender" = "$RND_SEAT" ] && other="$recv"
    case " $RND_PEERS " in
      *" $other "*) : ;;
      *) echo "  x  $f -- the Researcher seat only exchanges letters with: $RND_PEERS (see ai/roles/researcher.md); this drop-box should not exist"; bad=$((bad+1)) ;;
    esac
  fi
  [ "$recv" = "$sender" ] && { echo "  x  $f -- a seat sending itself mail; this file should not exist"; bad=$((bad+1)); }
  n=$(wc -l < "$f")
  [ "$n" -gt "$CAP" ] && { echo "  x  $f  $n lines / cap $CAP -- full does not mean raise the cap; it means nobody reads it or the letters are too fragmented"; bad=$((bad+1)); }
  rows=0
  while IFS= read -r line; do
    # Table data rows only: it has to start with |. **Prose and the intro also contain the word "read",
    # and without skipping them they get parsed as letters** (the first version reported 124 false reds that way).
    case "$line" in '|'*) ;; *) continue;; esac
    case "$line" in '|---'*|'| Date '*|'|Date'*) continue;; esac
    stripped=$(printf '%s' "$line" | tr -d '| ')
    [ -z "$stripped" ] && continue
    IFS='|' read -r _ c1 c2 c3 c4 c5 _rest <<< "$line"
    trim() { printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }
    d=$(trim "${c1:-}"); what=$(trim "${c2:-}"); where=$(trim "${c3:-}")
    typ=$(trim "${c4:-}"); reply=$(trim "${c5:-}")
    tag="$f: $(printf '%s' "$what" | cut -c1-24)"
    rows=$((rows+1))
    # (1) none of the five columns may be empty
    for pair in "Date:$d" "What I have to do:$what" "Where the detail is:$where" "Type:$typ" "Reply needed:$reply"; do
      [ -n "${pair#*:}" ] || { echo "  x  $tag -- the \"${pair%%:*}\" column is empty (write - when there is nothing)"; bad=$((bad+1)); }
    done
    # (2) date format and staleness
    if ! printf '%s' "$d" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
      echo "  x  $tag -- the date \"$d\" is not YYYY-MM-DD"; bad=$((bad+1))
    else
      ts=$(date -d "$d" +%s 2>/dev/null || echo "$today")
      age=$(( (today - ts) / 86400 ))
      [ "$age" -gt "$STALE_DAYS" ] && { echo "  x  stale $age days with nobody handling it: $tag -- either handle it, or the sender withdraws it and takes another route"; bad=$((bad+1)); }
    fi
    # (3) Type and Reply needed may only hold the defined values
    grep -qw -- "$typ" <<< "$TYPES" || { echo "  x  $tag -- \"Type\" says \"$typ\"; only these are allowed: $TYPES"; bad=$((bad+1)); }
    case "$reply" in yes|no) ;; *) echo "  x  $tag -- \"Reply needed\" says \"$reply\"; only \"yes\" or \"no\""; bad=$((bad+1));; esac
    # No chat loops: **a "reply" and a "notice" may never ask for a reply**.
    # The criterion (set by the Requester on 2026-09-15): **reply only when reading it raised a new question you cannot settle**;
    # if you did it, settled it yourself, or it was only a notice, **no reply at all** -- **the archive row is the receipt**.
    if [ "$reply" = "yes" ]; then
      case "$typ" in
        reply|notice) echo "  x  $tag -- type \"$typ\" may not ask for a reply (one round trip is the limit; open a task or an advisory task instead)"; bad=$((bad+1));;
      esac
    fi
    # Courtesy receipts are red on sight (the Requester: "things like 'got it, thanks, great suggestion' that do nothing need no reply").
    # How it judges: strike the courtesy words out one by one and **nothing is left** = this letter carries nothing to do.
    core=$(printf '%s' "$what" | sed 's/[`*"'"'"' .,;:!?()]//g')
    resid=$(printf '%s' "$core" | sed -e 's/[Gg]otit//g' -e 's/[Rr]eceived//g' -e 's/[Tt]hanks//g' -e 's/[Tt]hankyou//g' \
      -e 's/[Nn]oted//g' -e 's/[Uu]nderstood//g' -e 's/[Dd]one//g' -e 's/[Aa]greed//g' -e 's/[Aa]gree//g' \
      -e 's/[Yy]our//g' -e 's/suggestion//g' -e 's/proposal//g' -e 's/[Gg]reat//g' -e 's/[Gg]ood//g' -e 's/[Nn]ice//g' -e 's/[Oo][Kk]//g')
    if [ -z "$resid" ]; then
      echo "  x  $tag -- a courtesy receipt is not a letter (got it / thanks / great): if it carries nothing to do, do not send it; the archive row is the receipt"; bad=$((bad+1))
    fi
    # 🔴 Between the Developer and Reviewer seats, **any letter that mentions T-#### / B-#### is red**.
    # The Requester, 2026-09-15: "problems and feedback during development, especially between the developer and the reviewer,
    # **mostly do not go through letters** but through the project's existing agreed way of recording tasks,
    # **otherwise the development trail gets lost**".
    if { [ "$recv" = developer ] && [ "$sender" = reviewer ]; } || { [ "$recv" = reviewer ] && [ "$sender" = developer ]; }; then
      if printf '%s %s' "$what" "$where" | grep -qE '\b(T|B)-[0-9]{4}\b'; then
        echo "  x  $tag -- the Developer and Reviewer seats may not discuss tasks/bugs by mail: this one hangs off $(printf '%s %s' "$what" "$where" | grep -oE '\b(T|B)-[0-9]{4}\b' | sort -u | paste -sd' ' -); write it into that task/bug file (lose the ledger and you lose the development trail)"; bad=$((bad+1))
      fi
    fi
    # (4) "What I have to do" may not be just an ID (that is handing out work, which belongs in ai/tasks/ or ai/bugs/)
    idonly=$(printf '%s' "$what" | tr -d '`* ')
    if printf '%s' "$idonly" | grep -qE '^(T|B|AD|M)-[0-9]+$'; then
      echo "  x  $tag -- \"What I have to do\" is only an ID = handing out work through the mail; work goes to the ledger, the mail carries words"; bad=$((bad+1))
    fi
    # (5) the detail paths have to resolve (several separated by spaces or middots; - means none)
    if [ "$where" != "—" ] && [ "$where" != "-" ]; then
      # [Why not tr] `tr` substitutes **by byte**, and the CJK separators are multibyte, so it also rewrites bytes
      # inside a CJK filename -- **truncating the path into a name that does not exist and reporting a false red**
      # (measured and reported by the Supervisor seat on 2026-09-15). **Use sed, which works on characters.**
      for pth in $(printf '%s' "$where" | sed 's/[`·,]/ /g' | grep -oE '[A-Za-z0-9_./-]+/[^[:space:]]+' || true); do
        # [Test that the file exists, not what is appended] A letter often writes `ai/rules/laws.md:33` to point at a line.
        # What must hold is that **the file still exists**; the line number is not part of the path.
        # Without stripping it every such reference goes falsely red, and the only way to clear a false red
        # would be to drop the line number — **a rule that forces people to write less precisely**.
        pth="${pth%%:*}"
        [ -z "$pth" ] && continue
        [ -e "$pth" ] || { echo "  x  $tag -- the detail path does not resolve: $pth"; bad=$((bad+1)); }
      done
    fi
    # (6) never marked read in place
    case "$line" in *'~~'*) echo "  x  $tag -- the mailbox may not carry a strike-through; once handled, move it into archive/"; bad=$((bad+1));; esac
  done < "$f"

  # (7) the same letter sent twice (the same "what I have to do" appearing more than once in this file)
  dup=$(awk -F'|' '/^\|/ {
      if ($0 ~ /^\|---/) next; if ($0 ~ /^\| *Date /) next;
      what=$3; gsub(/^[ \t]+|[ \t]+$/, "", what); if (what == "") next; c[what]++
    } END { for (k in c) if (c[k] > 1) print c[k] " x " k }' "$f")
  if [ -n "$dup" ]; then
    while IFS= read -r line; do
      echo "  x  $f -- the same letter was sent more than once: $line (edit that one instead of sending another)"; bad=$((bad+1))
    done <<< "$dup"
  fi

  # 🔴 (7b) Developer seat <-> Reviewer seat: **this pair has almost no reason to mail at all**
  # The Requester, 2026-09-15: "the Reviewer and the Developer basically have no need to mail each other; the cases are very few".
  # So these two drop-boxes get two stricter rules: **only "request" or "notice"** (suggestion / hand-over / reply all mean
  # task talk is happening), and **at most 1 unhandled letter** (a second one means the mail is being used as a dev channel).
  if { [ "$recv" = developer ] && [ "$sender" = reviewer ]; } || { [ "$recv" = reviewer ] && [ "$sender" = developer ]; }; then
    badtyp=$(awk -F'|' '/^\|/ {
        if ($0 ~ /^\|---/) next; if ($0 ~ /^\| *Date /) next;
        what=$3; typ=$5; gsub(/^[ \t]+|[ \t]+$/, "", what); gsub(/^[ \t]+|[ \t]+$/, "", typ);
        if (what == "") next;
        if (typ != "request" && typ != "notice") print typ " <- " substr(what,1,24)
      }' "$f")
    if [ -n "$badtyp" ]; then
      while IFS= read -r line; do
        echo "  x  $f -- only \"request\" or \"notice\" is allowed between these two seats; this one is \"$line\": approach / verdict / task talk all go into T-#### or B-####"; bad=$((bad+1))
      done <<< "$badtyp"
    fi
    if [ "$rows" -gt 1 ]; then
      echo "  x  $f -- $rows unhandled letters between these two seats (cap 1): **they basically do not need to mail each other**; put the rest in the task or bug file"; bad=$((bad+1))
    fi
  fi

  # (8) piling up: more than MAIL_FLOOD non-notice letters unhandled in this file = an abnormal inbox, to be reported
  non=$(awk -F'|' '/^\|/ {
      if ($0 ~ /^\|---/) next; if ($0 ~ /^\| *Date /) next;
      what=$3; typ=$5; gsub(/^[ \t]+|[ \t]+$/, "", what); gsub(/^[ \t]+|[ \t]+$/, "", typ);
      if (what == "") next; if (typ == "notice") next; n++
    } END { print n+0 }' "$f")
  if [ "$non" -gt "$FLOOD" ]; then
    echo "  x  $f -- abnormal inbox: $sender has $non non-notice letters piled up (cap $FLOOD); either handle them this round, or tell the Requester and the sender \"stop sending here, open a task or an advisory task\""; bad=$((bad+1))
  fi
done

# (9) the archive: one file per seat per month, and every row states the outcome
# [Why the filename matters] One shared archive = all four seats appending to the same end of the same file,
# and **a git conflict is then a certainty** (pointed out by the Requester on 2026-09-15).
# **The archive belongs to the recipient**: a letter the Maintainer seat sent to the Supervisor seat is archived by the
# Supervisor seat into `supervisor-<YYYY-MM>.md` -- **a letter belongs to whoever it was sent to**.
for f in "$D"/archive/*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  if ! printf '%s' "$bn" | grep -qE "^(developer|reviewer|supervisor|maintainer|$RND_SEAT)-[0-9]{4}-[0-9]{2}\.md$"; then
    echo "  x  $f -- the archive filename must be one per seat per month: <seat>-<YYYY-MM>.md (one shared file guarantees git conflicts)"; bad=$((bad+1))
  fi
  while IFS= read -r line; do
    case "$line" in '|'*) ;; *) continue;; esac
    case "$line" in '|---'*|'| Date '*) continue;; esac
    stripped=$(printf '%s' "$line" | tr -d '| ')
    [ -z "$stripped" ] && continue
    res=$(printf '%s' "$line" | awk -F'|' '{print $(NF-1)}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -n "$res" ] || { echo "  x  $f -- an archive row does not state the outcome (did it / turned into T-#### / refused: reason)"; bad=$((bad+1)); }
  done < "$f"
done

# (10) all three drop-boxes exist for each of the four seats (a missing one means that pair cannot deliver)
for r in $SEATS; do
  for s in $SEATS; do
    [ "$r" = "$s" ] && continue
    [ -f "$D/to-$r/from-$s.md" ] || { echo "  x  $D/to-$r/from-$s.md is missing -- $s cannot deliver to $r"; bad=$((bad+1)); }
  done
done

# (11) Both drop-boxes must exist between the Researcher and each of its peers
# (the R&D line uses them; see ai/rules/layout.md 2, RandD/)
for peer in $RND_PEERS; do
  for pair in "to-$RND_SEAT/from-$peer.md" "to-$peer/from-$RND_SEAT.md"; do
    [ -f "$D/$pair" ] || { echo "  x  missing $D/$pair -- the Researcher and the $peer cannot post letters to each other"; bad=$((bad+1)); }
  done
done

if [ "$bad" -gt 0 ]; then
  echo
  echo "MAIL-FAIL ($bad)"
  echo "  The rules are in $D/README.md: unread only . move it into archive/<recipient>-<YYYY-MM>.md once handled . the mail carries words, the ledger carries work."
  exit 1
fi
echo "MAIL-OK ($(cat "$D"/to-*/from-*.md 2>/dev/null | grep -cE '^\| 2[0-9]{3}-' || true) unhandled, none overdue)"
