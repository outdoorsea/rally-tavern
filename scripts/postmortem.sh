#!/bin/bash
# Rally Tavern Post Mortem Management - Stop/Start/Continue

ACTION="$1"
shift

CONTRIBUTOR=$(ls overseers/profiles/*.yaml mayors/*.yaml 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.yaml//')
CONTRIBUTOR="${CONTRIBUTOR:-anonymous}"

# Detect contributor type
if [ -f "mayors/${CONTRIBUTOR}.yaml" ]; then
  CONTRIBUTOR_TYPE="mayor"
else
  CONTRIBUTOR_TYPE="overseer"
fi

case "$ACTION" in
  add)
    TITLE="$1"
    
    DATE=$(date +%Y-%m-%d)
    ID=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
    FILE="knowledge/postmortems/${DATE}-${ID}.yaml"
    
    cat > "$FILE" << EOF
id: $ID
title: $TITLE
date: $DATE
contributed_by: $CONTRIBUTOR
contributor_type: $CONTRIBUTOR_TYPE

context: |
  [What were you trying to do? What happened?]

# 🛑 STOP - What should we stop doing?
stop:
  - [Thing to stop doing]
  - [Another thing to stop]

# 🟢 START - What should we start doing?
start:
  - [Thing to start doing]
  - [Another thing to start]

# 🔄 CONTINUE - What's working? Keep doing it.
continue:
  - [Thing that works well]
  - [Another thing to continue]

outcome: |
  [What was the result after applying these lessons?]

tags: []
EOF
    
    echo "✓ Created post mortem: $FILE"
    echo ""
    echo "Fill in the Stop/Start/Continue sections:"
    echo "  🛑 STOP    - What to stop doing"
    echo "  🟢 START   - What to start doing"  
    echo "  🔄 CONTINUE - What's working"
    echo ""
    echo "Then: git add . && git commit -m '📋 Post mortem: $TITLE' && git push"
    ;;
    
  list)
    echo "📋 Post Mortems - Learn from Experience"
    echo ""
    for f in knowledge/postmortems/*.yaml; do
      [ -f "$f" ] || continue
      [[ "$f" == *"README"* ]] && continue
      
      title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
      date=$(grep "^date:" "$f" | cut -d: -f2 | xargs)
      type=$(grep "^contributor_type:" "$f" | cut -d: -f2 | xargs)
      
      [ "$type" = "mayor" ] && badge="🎩" || badge="👤"
      
      echo "  $badge [$date] $title"
    done
    ;;
    
  show)
    PM_ID="$1"
    FILE=$(find knowledge/postmortems -name "*${PM_ID}*.yaml" | head -1)
    
    if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
      echo "Post mortem not found: $PM_ID"
      exit 1
    fi
    
    title=$(grep "^title:" "$FILE" | cut -d: -f2- | xargs)
    echo "📋 $title"
    echo ""
    
    echo "🛑 STOP:"
    grep -A20 "^stop:" "$FILE" | grep "^  -" | sed 's/^  - /    /'
    
    echo ""
    echo "🟢 START:"
    grep -A20 "^start:" "$FILE" | grep "^  -" | sed 's/^  - /    /'
    
    echo ""
    echo "🔄 CONTINUE:"
    grep -A20 "^continue:" "$FILE" | grep "^  -" | sed 's/^  - /    /'
    ;;
    
  search)
    QUERY="$1"
    echo "🔍 Post mortems matching: $QUERY"
    grep -rl "$QUERY" knowledge/postmortems/*.yaml 2>/dev/null | while read f; do
      title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
      echo "  • $title"
      echo "    $f"
    done
    ;;
    
  *)
    echo "Usage: postmortem.sh <action> [args]"
    echo ""
    echo "Actions:"
    echo "  add <title>      - Create new post mortem"
    echo "  list             - List all post mortems"
    echo "  show <id>        - Show stop/start/continue"
    echo "  search <query>   - Search post mortems"
    echo ""
    echo "Post mortems use Stop/Start/Continue format:"
    echo "  🛑 STOP     - What to stop doing"
    echo "  🟢 START    - What to start doing"
    echo "  🔄 CONTINUE - What works, keep doing"
    ;;
esac
