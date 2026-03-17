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
    SEARCH_TERMS=()
    FILTER_TAG=""
    FILTER_CODEBASE=""
    FILTER_PLATFORM=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --tag) FILTER_TAG="$2"; shift 2;;
        --codebase) FILTER_CODEBASE="$2"; shift 2;;
        --platform) FILTER_PLATFORM="$2"; shift 2;;
        *) SEARCH_TERMS+=("$1"); shift;;
      esac
    done

    SCORE_FILE=$(mktemp)
    trap "rm -f '$SCORE_FILE'" EXIT

    for kfile in knowledge/*/*.yaml; do
      [ -f "$kfile" ] || continue
      content=$(cat "$kfile" 2>/dev/null) || continue
      echo "$content" | grep -q "^title:" || continue

      score=0

      # Apply filters (hard gates)
      if [ -n "$FILTER_TAG" ]; then
        echo "$content" | grep -qi "tags:.*${FILTER_TAG}" || continue
        score=$((score + 3))
      fi
      if [ -n "$FILTER_CODEBASE" ]; then
        echo "$content" | grep -qi "codebase_type:.*${FILTER_CODEBASE}" || continue
        score=$((score + 2))
      fi
      if [ -n "$FILTER_PLATFORM" ]; then
        echo "$content" | grep -qi "platform:.*${FILTER_PLATFORM}" || continue
        score=$((score + 2))
      fi

      # Term matching
      content_lower=$(echo "$content" | tr '[:upper:]' '[:lower:]')
      for term in "${SEARCH_TERMS[@]}"; do
        term_lower=$(echo "$term" | tr '[:upper:]' '[:lower:]')
        if echo "$content_lower" | grep -q "$term_lower"; then
          score=$((score + 3))
        fi
      done

      [ $score -eq 0 ] && continue

      # Verification bonus/penalty
      verified_by=$(echo "$content" | grep "^verified_by:" | head -1 | cut -d: -f2- | xargs 2>/dev/null || true)
      if [ -n "$verified_by" ] && [ "$verified_by" != "[]" ]; then
        score=$((score + 3))
      else
        score=$((score - 2))
      fi

      # Time decay — penalize old entries
      created_at=$(echo "$content" | grep "^created_at:" | head -1 | cut -d: -f2- | xargs 2>/dev/null || true)
      if [ -n "$created_at" ]; then
        created_date="${created_at%%T*}"
        if created_epoch=$(date -j -f "%Y-%m-%d" "$created_date" "+%s" 2>/dev/null); then
          now_epoch=$(date "+%s")
          age_days=$(( (now_epoch - created_epoch) / 86400 ))
          if [ $age_days -gt 0 ]; then
            decay=$(( age_days / 30 ))
            [ $decay -gt 5 ] && decay=5
            score=$((score - decay))
          fi
        fi
      fi

      [ $score -le 0 ] && continue

      title=$(echo "$content" | grep "^title:" | head -1 | cut -d: -f2- | xargs)
      echo "${score}|${kfile}|${title}" >> "$SCORE_FILE"
    done

    if [ -s "$SCORE_FILE" ]; then
      sort -t'|' -k1 -nr "$SCORE_FILE" | head -10 | while IFS='|' read -r score file title; do
        printf "  [%2d] %s — %s\n" "$score" "$file" "$title"
      done
    else
      echo "  No matches found."
    fi
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
