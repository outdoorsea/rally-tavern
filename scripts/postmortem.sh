#!/bin/bash
# Rally Tavern Post Mortem Management

ACTION="$1"
shift

CONTRIBUTOR=$(ls overseers/profiles/*.yaml mayors/*.yaml 2>/dev/null | head -1 | xargs -I{} basename {} .yaml)
CONTRIBUTOR="${CONTRIBUTOR:-anonymous}"

# Detect if contributor is mayor or overseer
if [ -f "mayors/${CONTRIBUTOR}.yaml" ]; then
  CONTRIBUTOR_TYPE="mayor"
elif [ -f "overseers/profiles/${CONTRIBUTOR}.yaml" ]; then
  CONTRIBUTOR_TYPE="overseer"
else
  CONTRIBUTOR_TYPE="unknown"
fi

case "$ACTION" in
  add)
    TITLE="$1"
    shift
    
    DATE=$(date +%Y-%m-%d)
    ID=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
    FILE="knowledge/postmortems/${DATE}-${ID}.yaml"
    
    SEVERITY="medium"
    while [[ $# -gt 0 ]]; do
      case $1 in
        --severity|-s) SEVERITY="$2"; shift 2;;
        *) shift;;
      esac
    done
    
    cat > "$FILE" << EOF
id: $ID
title: $TITLE
date: $DATE
severity: $SEVERITY
contributed_by: $CONTRIBUTOR
contributor_type: $CONTRIBUTOR_TYPE

summary: |
  [Brief summary of what happened]

what_happened: |
  [Detailed timeline]

root_cause: |
  [Why did this happen?]

resolution: |
  [How was it fixed?]

lessons:
  - [Lesson 1]
  - [Lesson 2]

prevention: |
  [How to prevent this in the future]

tags: []
EOF
    
    echo "✓ Created post mortem: $FILE"
    echo "  Edit to fill in details"
    git add "$FILE"
    ;;
    
  list)
    echo "📋 Post Mortems"
    echo ""
    for f in knowledge/postmortems/*.yaml 2>/dev/null; do
      [ -f "$f" ] || continue
      title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
      date=$(grep "^date:" "$f" | cut -d: -f2 | xargs)
      severity=$(grep "^severity:" "$f" | cut -d: -f2 | xargs)
      type=$(grep "^contributor_type:" "$f" | cut -d: -f2 | xargs)
      
      case "$severity" in
        critical) icon="🔴";;
        high) icon="🟠";;
        medium) icon="🟡";;
        *) icon="🟢";;
      esac
      
      echo "  $icon [$date] $title (by $type)"
    done
    ;;
    
  *)
    echo "Usage: postmortem.sh <action> [args]"
    echo ""
    echo "Actions:"
    echo "  add <title> [--severity low|medium|high|critical]"
    echo "  list"
    ;;
esac
