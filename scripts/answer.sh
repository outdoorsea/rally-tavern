#!/bin/bash
# Answer a looking-for bounty with a link/solution

BOUNTY_ID="$1"
ANSWER="$2"

FILE="bounties/open/${BOUNTY_ID}.yaml"

if [ ! -f "$FILE" ]; then
  echo "Bounty not found: $BOUNTY_ID"
  exit 1
fi

TYPE=$(grep "^type:" "$FILE" | cut -d: -f2 | xargs)
if [ "$TYPE" != "looking-for" ] && [ "$TYPE" != "explain" ]; then
  echo "This bounty type ($TYPE) should be claimed, not answered."
  echo "Use: ./scripts/claim.sh $BOUNTY_ID"
  exit 1
fi

# Add answer to the bounty
cat >> "$FILE" << EOF

answers:
  - by: $(git config user.name)
    at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
    answer: |
      $ANSWER
EOF

echo "✓ Answered $BOUNTY_ID"
echo "  If this resolves the bounty, poster should close it."
git add "$FILE"
