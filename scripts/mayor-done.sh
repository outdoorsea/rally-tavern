#!/bin/bash
# Signal Mayor has completed work

MAYOR="$1"
FILE="coordination/mayors/${MAYOR}-intent.yaml"

if [ ! -f "$FILE" ]; then
  echo "No active intent found for: $MAYOR"
  exit 1
fi

sed -i '' 's/^status: active/status: completed/' "$FILE"
echo "completed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$FILE"

echo "✓ 🎩 $MAYOR marked work as complete"
git add "$FILE"
