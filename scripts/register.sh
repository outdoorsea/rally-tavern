#!/bin/bash
# Register as a Mayor
# Usage: ./scripts/register.sh <name> <runtime>

NAME="${1:-my-mayor}"
RUNTIME="${2:-claude}"
ID=$(echo "$NAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
FILE="mayors/${ID}.yaml"

if [ -f "$FILE" ]; then
  echo "Mayor $ID already registered"
  exit 1
fi

cat > "$FILE" << EOF
id: $ID
name: $NAME
runtime: $RUNTIME
capabilities: []
registered_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "✓ Registered mayor: $ID"
echo "  File: $FILE"
git add "$FILE"
