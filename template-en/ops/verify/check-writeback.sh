#!/usr/bin/env bash
# check-writeback: did what was changed on the real machine actually get back into the repo?
# Usage: bash ops/verify/check-writeback.sh
# Exit codes: 0 = nothing parked; 1 = something is (listed).
#
# [Why this exists] When the Developer seat changes something on the real machine, it must write back to the repo
# the same round -- **the repo is the source, the real machine is a volatile live network**.
# But the Windows side often refuses the write (the file is held by an editor or by Defender), and that produces
# a silent fork: "changed the real machine, never wrote back to the repo". Next stage someone starts from the repo
# and overwrites the change on the real machine, **and neither side reports an error**.
#
# The backstop convention: whatever will not write goes **into `tmp/writeback-pending/`**, with the report saying so.
# This guard judges whether that directory is empty -- **empty = nothing parked**.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
D="tmp/writeback-pending"
n=0
[ -d "$D" ] && n=$(find "$D" -type f ! -name '.gitkeep' | wc -l)
if [ "$n" -gt 0 ]; then
  echo "  ✗  $D still holds $n changes not merged into the repo:"
  find "$D" -type f ! -name '.gitkeep' | sed 's/^/     /' | head -20
  echo
  echo "WRITEBACK-FAIL ($n not written back)"
  echo "  Developer seat: try the four-step ladder in docs/ops/realmachine.md once more (normal write-back -> the rename trick -> change path -> ask for permission)."
  echo "  Empty this directory once they are merged in. **Parked is not delivered.**"
  exit 1
fi
echo "WRITEBACK-OK (nothing parked)"
