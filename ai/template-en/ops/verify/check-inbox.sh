#!/usr/bin/env bash
# check-inbox: does the inbox still have lines with no disposition?
# Usage: from the repo root, bash ops/verify/check-inbox.sh
# Exit 0 = everything has a destination; 1 = something is still `pending`
#          (the Reviewer seat may not end a round with any).
#
# Why this guard: the Requester only talks to the Reviewer, and every single thing he says
# has to come back with an answer. Relying on someone to remember "what else did he mention"
# does not work -- interrupt three times in one round and the second one evaporates.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/CLAUDE.md" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/CLAUDE.md" ] || { echo "cannot find the repo root"; exit 2; }
INBOX="$ROOT/product/requirements/inbox.md"
[ -f "$INBOX" ] || { echo "cannot find the inbox $INBOX"; exit 2; }

# Table rows: start with |, second cell is a number; skip template example rows (they contain <)
pending=$(grep -E '^\|[[:space:]]*[0-9]+[[:space:]]*\|' "$INBOX" | grep -v '<' | grep -E '\|[[:space:]]*(pending)[[:space:]]*\|?[[:space:]]*$')
waiting=$(grep -E '^\|[[:space:]]*[0-9]+[[:space:]]*\|' "$INBOX" | grep -v '<' | grep -E '\|[[:space:]]*(awaiting the Requester)[[:space:]]*\|?[[:space:]]*$')

[ -n "$waiting" ] && { echo "== waiting on the Requester's call (not undisposed, but do not forget to chase) =="; printf '%s\n' "$waiting" | cut -c1-120; echo; }

if [ -n "$pending" ]; then
  echo "== X still without a destination (must be zero before the round ends) =="
  printf '%s\n' "$pending" | cut -c1-120
  echo
  echo "INBOX-FAIL: every line needs a disposition -- task opened / spec / answered / won't do (say why)."
  exit 1
fi
echo "INBOX-OK (no pending lines in the inbox)"
