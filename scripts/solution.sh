#!/bin/bash
# Quick solutions lookup and add
source "$(dirname "$0")/../lib/common.sh"

ACTION="${1:-search}"
shift

case "$ACTION" in
  search)
    QUERY="$*"
    echo "💡 Searching solutions for: $QUERY"
    echo ""
    
    for f in knowledge/solutions/*.yaml; do
      [[ -f "$f" ]] || continue
      [[ "$f" =~ README ]] && continue
      
      if grep -qi "$QUERY" "$f" 2>/dev/null; then
        problem=$(yaml_get "$f" "problem")
        solution=$(grep -A1 "^solution:" "$f" | tail -1 | xargs)
        echo "📍 $(basename "$f" .yaml)"
        echo "   Problem: $problem"
        echo "   Solution: ${solution:0:80}..."
        echo ""
      fi
    done
    ;;
    
  add)
    TITLE="$1"
    shift
    
    PROBLEM=""
    SOLUTION=""
    TAGS=""
    
    while [[ $# -gt 0 ]]; do
      case $1 in
        --problem|-p) PROBLEM="$2"; shift 2;;
        --solution|-s) SOLUTION="$2"; shift 2;;
        --tags|-t) TAGS="$2"; shift 2;;
        *) shift;;
      esac
    done
    
    ID=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
    FILE="knowledge/solutions/${ID}.yaml"
    
    IDENTITY=$(get_identity)
    CONTRIBUTOR="${IDENTITY#*:}"
    
    cat > "$FILE" << EOF
id: $ID
problem: $TITLE
solution: |
  ${SOLUTION:-TODO: Add solution}
works_with: []
contributed_by: $CONTRIBUTOR
verified_by: []
tags: [${TAGS}]
created_at: $(timestamp)
EOF
    
    log_success "Created solution: $FILE"
    echo "Edit to add full solution, then commit."
    git add "$FILE"
    ;;
    
  list)
    echo "💡 All Solutions"
    echo ""
    for f in knowledge/solutions/*.yaml; do
      [[ -f "$f" ]] || continue
      [[ "$f" =~ README ]] && continue
      problem=$(yaml_get "$f" "problem")
      echo "  • $(basename "$f" .yaml)"
      echo "    $problem"
    done
    ;;
    
  *)
    echo "Usage: solution.sh <action> [args]"
    echo ""
    echo "Actions:"
    echo "  search <query>     - Search solutions"
    echo "  add <title>        - Add new solution"
    echo "  list               - List all solutions"
    echo ""
    echo "Philosophy: Search before you build. Share after you solve."
    ;;
esac
