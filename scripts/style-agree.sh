#!/bin/bash
# Create or update style agreement

LANGUAGE="$1"

if [ -z "$LANGUAGE" ]; then
  echo "Usage: style-agree.sh <language>"
  echo "Example: style-agree.sh python"
  exit 1
fi

mkdir -p coordination/style
FILE="coordination/style/${LANGUAGE}-style.yaml"

if [ -f "$FILE" ]; then
  echo "Style agreement exists: $FILE"
  echo "Edit directly to update."
  cat "$FILE"
  exit 0
fi

cat > "$FILE" << EOF
language: $LANGUAGE
created_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
agreed_by: []
conventions:
  - # Add conventions here
  - # Example: Use type hints everywhere
  - # Example: 88 char line length
EOF

echo "✓ Created style agreement: $FILE"
echo "  Edit to add conventions, then have Mayors add their names to agreed_by"
