#!/bin/bash
# Check if an area/file is claimed

QUERY="$1"

if [ -z "$QUERY" ]; then
  echo "Usage: check-area.sh <file-or-area>"
  exit 1
fi

echo "🔍 Checking claims for: $QUERY"
echo ""

FOUND=0
for f in coordination/claims/*.yaml; do
  [ -f "$f" ] || continue
  
  # Check if query matches area name or files
  if grep -qi "$QUERY" "$f"; then
    FOUND=1
    area=$(grep "^area:" "$f" | cut -d: -f2- | xargs)
    by=$(grep "^claimed_by:" "$f" | cut -d: -f2 | xargs)
    desc=$(grep "^description:" "$f" | cut -d: -f2- | xargs)
    since=$(grep "^claimed_at:" "$f" | cut -d: -f2- | xargs)
    
    echo "⚠️  CLAIMED by $by"
    echo "   Area: $area"
    echo "   Doing: $desc"
    echo "   Since: ${since:0:10}"
    echo ""
  fi
done

if [ $FOUND -eq 0 ]; then
  echo "✅ No active claims found. Safe to work on."
fi
