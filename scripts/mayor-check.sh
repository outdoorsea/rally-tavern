#!/bin/bash
# Check if a Mayor is working on an area

QUERY="$1"

echo "🔍 Checking Mayor activity for: $QUERY"
echo ""

FOUND=0
for f in coordination/mayors/*-intent.yaml; do
  [ -f "$f" ] || continue
  
  status=$(grep "^status:" "$f" | cut -d: -f2 | xargs)
  [ "$status" != "active" ] && continue
  
  if grep -qi "$QUERY" "$f"; then
    FOUND=1
    mayor=$(grep "^mayor:" "$f" | cut -d: -f2 | xargs)
    intent=$(grep "^intent:" "$f" | cut -d: -f2- | xargs)
    scope=$(grep "^scope:" "$f" | cut -d: -f2- | xargs)
    
    echo "⚠️  🎩 $mayor is working here"
    echo "   Intent: $intent"
    echo "   Scope: $scope"
    echo ""
  fi
done

if [ $FOUND -eq 0 ]; then
  echo "✅ No active Mayor work in this area"
fi
