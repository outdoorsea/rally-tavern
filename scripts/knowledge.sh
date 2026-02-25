#!/bin/bash
# Rally Tavern Knowledge Management

ACTION="$1"
shift

MAYOR=$(ls mayors/*.yaml 2>/dev/null | head -1 | xargs -I{} basename {} .yaml)
MAYOR="${MAYOR:-anonymous}"

case "$ACTION" in
  add)
    TYPE="$1"
    TITLE="$2"
    shift 2
    
    ID="$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')"
    FILE="knowledge/${TYPE}s/${ID}.yaml"
    
    echo "id: $ID" > "$FILE"
    echo "title: $TITLE" >> "$FILE"
    echo "contributed_by: $MAYOR" >> "$FILE"
    echo "created_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$FILE"
    echo "verified_by: []" >> "$FILE"
    
    # Parse additional args
    while [[ $# -gt 0 ]]; do
      case $1 in
        --summary) echo "summary: $2" >> "$FILE"; shift 2;;
        --codebase) echo "codebase_type: $2" >> "$FILE"; shift 2;;
        --platform) echo "platform: $2" >> "$FILE"; shift 2;;
        --repo) echo "repo: $2" >> "$FILE"; shift 2;;
        --lesson) echo "lesson: |"$'\n'"  $2" >> "$FILE"; shift 2;;
        --context) echo "context: $2" >> "$FILE"; shift 2;;
        --tags) echo "tags: [$2]" >> "$FILE"; shift 2;;
        *) shift;;
      esac
    done
    
    echo "✓ Added knowledge: $FILE"
    echo "  Edit to add more details, then commit."
    git add "$FILE"
    ;;
    
  verify)
    FILE="$1"
    if [ ! -f "$FILE" ]; then
      echo "File not found: $FILE"
      exit 1
    fi
    
    # Add mayor to verified_by list
    if grep -q "verified_by:.*\[$MAYOR\]" "$FILE" || grep -q "verified_by:.*$MAYOR" "$FILE"; then
      echo "Already verified by $MAYOR"
    else
      sed -i '' "s/verified_by: \[/verified_by: [$MAYOR, /" "$FILE"
      echo "✓ Verified by $MAYOR"
      git add "$FILE"
    fi
    ;;
    
  search)
    QUERY=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --tag) grep -rl "tags:.*$2" knowledge/ 2>/dev/null; shift 2;;
        --codebase) grep -rl "codebase_type: $2" knowledge/ 2>/dev/null; shift 2;;
        --platform) grep -rl "platform: $2" knowledge/ 2>/dev/null; shift 2;;
        *) grep -rl "$1" knowledge/ 2>/dev/null; shift;;
      esac
    done
    ;;
    
  list)
    echo "📚 Rally Tavern Knowledge"
    echo ""
    for dir in knowledge/*/; do
      [ -d "$dir" ] || continue
      type=$(basename "$dir")
      count=$(ls "$dir"/*.yaml 2>/dev/null | wc -l | xargs)
      echo "  $type: $count items"
    done
    ;;
    
  *)
    echo "Usage: knowledge.sh <action> [args]"
    echo ""
    echo "Actions:"
    echo "  add <type> <title> [--summary ...] [--tags ...]"
    echo "  verify <file>"
    echo "  search <query> | --tag <tag> | --codebase <type>"
    echo "  list"
    ;;
esac
