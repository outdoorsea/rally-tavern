#!/bin/bash
# Mayor completes a bounty
# Usage: ./scripts/mayor-complete.sh <mayor-name> <bounty-id> [--summary "..."] [--json]

MAYOR="$1"
BOUNTY_ID="$2"
shift 2

SUMMARY=""
JSON_OUTPUT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --summary|-s) SUMMARY="$2"; shift 2;;
    --json) JSON_OUTPUT="yes"; shift;;
    *) shift;;
  esac
done

CLAIMED_FILE="bounties/claimed/${BOUNTY_ID}.yaml"
DONE_FILE="bounties/done/${BOUNTY_ID}.yaml"

if [ ! -f "$CLAIMED_FILE" ]; then
  [ "$JSON_OUTPUT" ] && echo '{"success": false, "error": "not_claimed"}' || echo "❌ Not claimed: $BOUNTY_ID"
  exit 1
fi

# Verify it's claimed by this mayor
CLAIMED_BY=$(grep "^claimed_by:" "$CLAIMED_FILE" | cut -d: -f2 | xargs)
if [ "$CLAIMED_BY" != "$MAYOR" ]; then
  [ "$JSON_OUTPUT" ] && echo "{\"success\": false, \"error\": \"claimed_by_other\", \"claimed_by\": \"$CLAIMED_BY\"}" || echo "❌ Claimed by $CLAIMED_BY, not $MAYOR"
  exit 1
fi

mv "$CLAIMED_FILE" "$DONE_FILE"
echo "completed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$DONE_FILE"
echo "completed_by: $MAYOR" >> "$DONE_FILE"
[ -n "$SUMMARY" ] && echo "summary: |"$'\n'"  $SUMMARY" >> "$DONE_FILE"

git add bounties/

if [ "$JSON_OUTPUT" ]; then
  echo "{\"success\": true, \"bounty_id\": \"$BOUNTY_ID\", \"completed_by\": \"$MAYOR\"}"
else
  echo "✓ 🎩 Completed by $MAYOR: $BOUNTY_ID"
fi
