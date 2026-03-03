#!/bin/bash
# Rally Tavern Repository Management

ACTION="$1"
shift

MAYOR=$(ls mayors/*.yaml 2>/dev/null | head -1 | xargs -I{} basename {} .yaml)
MAYOR="${MAYOR:-anonymous}"

case "$ACTION" in
  add)
    REPO="$1"
    shift
    
    CATEGORY="uncategorized"
    WHY=""
    TAGS=""
    
    while [[ $# -gt 0 ]]; do
      case $1 in
        --category|-c) CATEGORY="$2"; shift 2;;
        --why|-w) WHY="$2"; shift 2;;
        --tags|-t) TAGS="$2"; shift 2;;
        *) shift;;
      esac
    done
    
    # Extract repo name for filename
    REPO_NAME=$(echo "$REPO" | tr '/' '-')
    FILE="knowledge/repos/${CATEGORY}/${REPO_NAME}.yaml"
    mkdir -p "knowledge/repos/${CATEGORY}"
    
    cat > "$FILE" << EOF
repo: $REPO
url: https://github.com/$REPO
category: $CATEGORY
contributed_by: $MAYOR
added_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
why: |
  $WHY
tags: [${TAGS}]
EOF
    
    echo "✓ Added repo: $REPO"
    echo "  File: $FILE"
    echo "  Edit to add more details (use_for, related, etc.)"
    git add "$FILE"
    ;;
    
  list)
    CATEGORY="${1:-all}"
    echo "🔗 Rally Tavern Repos"
    echo ""
    
    if [ "$CATEGORY" = "all" ]; then
      for dir in knowledge/repos/*/; do
        [ -d "$dir" ] || continue
        cat=$(basename "$dir")
        [ "$cat" = "README.md" ] && continue
        echo "=== $cat ==="
        for f in "$dir"*.yaml; do
          [ -f "$f" ] || continue
          repo=$(grep "^repo:" "$f" | cut -d: -f2- | xargs)
          why=$(grep -A1 "^why:" "$f" | tail -1 | xargs)
          echo "  • $repo"
          echo "    $why"
        done
        echo ""
      done
    else
      for f in knowledge/repos/"$CATEGORY"/*.yaml; do
        [ -f "$f" ] || continue
        repo=$(grep "^repo:" "$f" | cut -d: -f2- | xargs)
        why=$(grep -A1 "^why:" "$f" | tail -1 | xargs)
        echo "• $repo"
        echo "  $why"
      done
    fi
    ;;
    
  search)
    QUERY="$1"
    echo "🔍 Searching repos for: $QUERY"
    grep -rl "$QUERY" knowledge/repos/ 2>/dev/null | while read f; do
      repo=$(grep "^repo:" "$f" | cut -d: -f2- | xargs)
      echo "  • $repo ($f)"
    done
    ;;
    
  *)
    echo "Usage: repos.sh <action> [args]"
    echo ""
    echo "Actions:"
    echo "  add <owner/repo> --category <cat> --why \"reason\" [--tags \"a,b\"]"
    echo "  list [category]"
    echo "  search <query>"
    echo ""
    echo "Categories: ai-agents, dev-tools, templates, libraries, learning"
    ;;
esac
