#!/bin/bash
# Announce Mayor's intent to work on an area

MAYOR="$1"
INTENT="$2"
SCOPE="$3"
DURATION="${4:-2h}"

if [ -z "$MAYOR" ] || [ -z "$INTENT" ]; then
  echo "Usage: mayor-intent.sh <mayor-name> <intent> [scope] [duration]"
  echo "Example: mayor-intent.sh myndy-mayor 'Refactoring auth' 'src/auth/*' '2h'"
  exit 1
fi

mkdir -p coordination/mayors
FILE="coordination/mayors/${MAYOR}-intent.yaml"

cat > "$FILE" << EOF
mayor: $MAYOR
intent: $INTENT
scope: ${SCOPE:-unspecified}
timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
expected_duration: $DURATION
status: active
EOF

echo "🎩 Mayor intent announced: $MAYOR"
echo "   Intent: $INTENT"
echo "   Scope: ${SCOPE:-unspecified}"
git add "$FILE"
