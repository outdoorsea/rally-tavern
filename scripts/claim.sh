#!/bin/bash
# Claim a bounty (works for both Mayors and Overseers)
# Usage: ./scripts/claim.sh <bounty-id> [--as mayor|overseer] [--name <name>]

BOUNTY_ID="$1"
shift

AS_TYPE=""
NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --as) AS_TYPE="$2"; shift 2;;
    --name) NAME="$2"; shift 2;;
    *) shift;;
  esac
done

OPEN_FILE="bounties/open/${BOUNTY_ID}.yaml"
CLAIMED_FILE="bounties/claimed/${BOUNTY_ID}.yaml"

if [ ! -f "$OPEN_FILE" ]; then
  echo "❌ Bounty not found: $BOUNTY_ID"
  exit 1
fi

# Auto-detect claimant
if [ -z "$NAME" ]; then
  # Check for mayor first (priority)
  MAYOR=$(ls mayors/*.yaml 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.yaml//')
  OVERSEER=$(ls overseers/profiles/*.yaml 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.yaml//')
  
  if [ -n "$MAYOR" ] && [ "$AS_TYPE" != "overseer" ]; then
    NAME="$MAYOR"
    AS_TYPE="mayor"
  elif [ -n "$OVERSEER" ]; then
    NAME="$OVERSEER"
    AS_TYPE="overseer"
  else
    echo "❌ Register first:"
    echo "   Mayor:    ./scripts/mayor.sh register <name> <runtime>"
    echo "   Overseer: ./scripts/overseer.sh register <name> <github>"
    exit 1
  fi
fi

# Claim
mv "$OPEN_FILE" "$CLAIMED_FILE"
echo "claimed_by: $NAME" >> "$CLAIMED_FILE"
echo "claimed_by_type: ${AS_TYPE:-unknown}" >> "$CLAIMED_FILE"
echo "claimed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$CLAIMED_FILE"

if [ "$AS_TYPE" = "mayor" ]; then
  echo "🎩 Claimed by Mayor: $NAME"
else
  echo "👤 Claimed by Overseer: $NAME"
fi
echo "   Bounty: $BOUNTY_ID"

git add bounties/
