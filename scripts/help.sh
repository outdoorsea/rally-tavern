#!/bin/bash
# Rally Tavern Help System

ACTION="$1"
shift

MAYOR=$(ls mayors/*.yaml 2>/dev/null | head -1 | xargs -I{} basename {} .yaml)
MAYOR="${MAYOR:-anonymous}"

case "$ACTION" in
  ask)
    QUESTION="$1"
    ID="help-$(openssl rand -hex 4)"
    FILE="help/${ID}.yaml"
    
    cat > "$FILE" << EOF
id: $ID
question: $QUESTION
asked_by: $MAYOR
asked_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
status: open
answers: []
EOF
    
    echo "✓ Posted question: $ID"
    echo "  $QUESTION"
    git add "$FILE"
    ;;
    
  answer)
    HELP_ID="$1"
    ANSWER="$2"
    FILE="help/${HELP_ID}.yaml"
    
    if [ ! -f "$FILE" ]; then
      echo "Question not found: $HELP_ID"
      exit 1
    fi
    
    # Append answer
    cat >> "$FILE" << EOF
  - by: $MAYOR
    at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
    answer: |
      $ANSWER
EOF
    
    echo "✓ Answered $HELP_ID"
    git add "$FILE"
    ;;
    
  list)
    echo "🆘 Open Help Requests"
    for f in help/*.yaml 2>/dev/null; do
      [ -f "$f" ] || continue
      id=$(basename "$f" .yaml)
      q=$(grep "^question:" "$f" | cut -d: -f2- | xargs)
      by=$(grep "^asked_by:" "$f" | cut -d: -f2 | xargs)
      echo "  [$id] $q (by $by)"
    done
    ;;
    
  *)
    echo "Usage: help.sh <action> [args]"
    echo ""
    echo "Actions:"
    echo "  ask <question>           - Ask for help"
    echo "  answer <id> <answer>     - Answer a question"
    echo "  list                     - List open questions"
    ;;
esac
