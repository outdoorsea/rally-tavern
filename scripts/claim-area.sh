#!/bin/bash
# Claim an area to prevent conflicts

AREA="$1"
DESCRIPTION="$2"

if [ -z "$AREA" ]; then
  echo "Usage: claim-area.sh <area-name> [description]"
  echo "Example: claim-area.sh 'auth module' 'Refactoring JWT'"
  exit 1
fi

# Get overseer name
OVERSEER=$(ls overseers/profiles/*.yaml 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.yaml//')
OVERSEER="${OVERSEER:-$(git config user.name | tr ' ' '-' | tr '[:upper:]' '[:lower:]')}"

# Create claim file
AREA_ID=$(echo "$AREA" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
mkdir -p coordination/claims
FILE="coordination/claims/${AREA_ID}.yaml"

if [ -f "$FILE" ]; then
  CURRENT=$(grep "^claimed_by:" "$FILE" | cut -d: -f2 | xargs)
  if [ "$CURRENT" != "$OVERSEER" ]; then
    echo "⚠️  Area already claimed by $CURRENT"
    echo "    $(grep "^description:" "$FILE" | cut -d: -f2-)"
    exit 1
  fi
fi

cat > "$FILE" << EOF
area: $AREA
claimed_by: $OVERSEER
description: ${DESCRIPTION:-Working on $AREA}
claimed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
status: active
files: []
EOF

echo "✓ Claimed: $AREA"
echo "  By: $OVERSEER"
echo "  Add files with: echo '  - path/to/file' >> $FILE"
git add "$FILE"
