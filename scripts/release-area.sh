#!/bin/bash
# Release a claimed area

AREA="$1"
AREA_ID=$(echo "$AREA" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
FILE="coordination/claims/${AREA_ID}.yaml"

if [ ! -f "$FILE" ]; then
  echo "Claim not found: $AREA"
  exit 1
fi

# Move to released
mkdir -p coordination/released
mv "$FILE" "coordination/released/${AREA_ID}-$(date +%Y%m%d).yaml"

echo "✓ Released: $AREA"
git add coordination/
