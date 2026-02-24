#!/bin/bash
# Claim a bounty
# Usage: ./scripts/claim.sh <bounty-id>

BOUNTY_ID="$1"
OPEN_FILE="bounties/open/${BOUNTY_ID}.yaml"
CLAIMED_FILE="bounties/claimed/${BOUNTY_ID}.yaml"

if [ ! -f "$OPEN_FILE" ]; then
  echo "Bounty $BOUNTY_ID not found in open/"
  exit 1
fi

# Get current mayor
MAYOR=$(ls mayors/*.yaml 2>/dev/null | head -1 | xargs -I{} basename {} .yaml)
if [ -z "$MAYOR" ]; then
  echo "Register as a mayor first: ./scripts/register.sh <name>"
  exit 1
fi

# Move and update
mv "$OPEN_FILE" "$CLAIMED_FILE"
echo "claimed_by: $MAYOR" >> "$CLAIMED_FILE"
echo "claimed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$CLAIMED_FILE"

echo "✓ Claimed: $BOUNTY_ID"
echo "  By: $MAYOR"
git add bounties/
