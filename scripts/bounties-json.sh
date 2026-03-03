#!/bin/bash
# List bounties in JSON format for Mayors

echo "["
FIRST=1
for f in bounties/open/*.yaml; do
  [ -f "$f" ] || continue
  [[ "$f" == *".gitkeep"* ]] && continue
  
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  type=$(grep "^type:" "$f" | cut -d: -f2 | xargs)
  priority=$(grep "^priority:" "$f" | cut -d: -f2 | xargs)
  desc=$(grep -A5 "^description:" "$f" | tail -4 | tr '\n' ' ' | xargs)
  tags=$(grep "^tags:" "$f" | cut -d: -f2- | xargs)
  
  [ $FIRST -eq 0 ] && echo ","
  FIRST=0
  
  cat << EOF
  {
    "id": "$id",
    "title": "$title",
    "type": "${type:-build}",
    "priority": ${priority:-3},
    "description": "$desc",
    "tags": $tags
  }
EOF
done
echo ""
echo "]"
