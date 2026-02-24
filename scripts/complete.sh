#!/bin/bash
# Complete a bounty
# Usage: ./scripts/complete.sh <bounty-id> [--summary "..."]

BOUNTY_ID="$1"
shift
SUMMARY=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --summary|-s) SUMMARY="$2"; shift 2;;
    *) shift;;
  esac
done

CLAIMED_FILE="bounties/claimed/${BOUNTY_ID}.yaml"
DONE_FILE="bounties/done/${BOUNTY_ID}.yaml"

if [ ! -f "$CLAIMED_FILE" ]; then
  echo "Bounty $BOUNTY_ID not found in claimed/"
  exit 1
fi

mv "$CLAIMED_FILE" "$DONE_FILE"
echo "completed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$DONE_FILE"
[ -n "$SUMMARY" ] && echo "result: $SUMMARY" >> "$DONE_FILE"

echo "✓ Completed: $BOUNTY_ID"
git add bounties/
