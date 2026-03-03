#!/bin/bash
# Mayor claims a bounty (optimized for AI use)
# Usage: ./scripts/mayor-claim.sh <mayor-name> <bounty-id> [--json]

MAYOR="$1"
BOUNTY_ID="$2"
JSON_OUTPUT="$3"

if [ -z "$MAYOR" ] || [ -z "$BOUNTY_ID" ]; then
  echo "Usage: mayor-claim.sh <mayor-name> <bounty-id> [--json]"
  exit 1
fi

OPEN_FILE="bounties/open/${BOUNTY_ID}.yaml"
CLAIMED_FILE="bounties/claimed/${BOUNTY_ID}.yaml"

# Check bounty exists
if [ ! -f "$OPEN_FILE" ]; then
  if [ "$JSON_OUTPUT" = "--json" ]; then
    echo '{"success": false, "error": "bounty_not_found"}'
  else
    echo "❌ Bounty not found: $BOUNTY_ID"
  fi
  exit 1
fi

# Check not already claimed
if [ -f "$CLAIMED_FILE" ]; then
  if [ "$JSON_OUTPUT" = "--json" ]; then
    echo '{"success": false, "error": "already_claimed"}'
  else
    echo "❌ Already claimed: $BOUNTY_ID"
  fi
  exit 1
fi

# Claim it
mv "$OPEN_FILE" "$CLAIMED_FILE"
echo "claimed_by: $MAYOR" >> "$CLAIMED_FILE"
echo "claimed_by_type: mayor" >> "$CLAIMED_FILE"
echo "claimed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$CLAIMED_FILE"

git add bounties/

if [ "$JSON_OUTPUT" = "--json" ]; then
  TITLE=$(grep "^title:" "$CLAIMED_FILE" | cut -d: -f2- | xargs)
  echo "{\"success\": true, \"bounty_id\": \"$BOUNTY_ID\", \"claimed_by\": \"$MAYOR\", \"title\": \"$TITLE\"}"
else
  echo "🎩 Claimed by Mayor: $MAYOR"
  echo "   Bounty: $BOUNTY_ID"
  grep "^title:" "$CLAIMED_FILE"
fi
