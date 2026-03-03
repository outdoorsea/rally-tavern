#!/bin/bash
# Post or view today's focus

mkdir -p coordination/today

if [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
  echo "📅 Today's Focus"
  echo ""
  DATE=$(date +%Y-%m-%d)
  for f in coordination/today/*.yaml; do
    [ -f "$f" ] || continue
    updated=$(grep "^updated:" "$f" | cut -d: -f2- | xargs)
    [[ "$updated" == "$DATE"* ]] || continue
    
    who=$(grep "^overseer:" "$f" | cut -d: -f2 | xargs)
    focus=$(grep "^focus:" "$f" | cut -d: -f2- | xargs)
    echo "  👤 $who: $focus"
  done
  exit 0
fi

FOCUS="$1"
if [ -z "$FOCUS" ]; then
  echo "Usage: today.sh <what you're working on>"
  echo "       today.sh --list"
  exit 1
fi

OVERSEER=$(ls overseers/profiles/*.yaml 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.yaml//')
OVERSEER="${OVERSEER:-$(git config user.name | tr ' ' '-' | tr '[:upper:]' '[:lower:]')}"

FILE="coordination/today/${OVERSEER}.yaml"

cat > "$FILE" << EOF
overseer: $OVERSEER
focus: $FOCUS
updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "✓ Posted today's focus"
echo "  $FOCUS"
git add "$FILE"
