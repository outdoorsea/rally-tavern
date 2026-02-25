#!/bin/bash
# Rally Tavern Mayor Management

ACTION="$1"
shift

case "$ACTION" in
  register)
    NAME="$1"
    RUNTIME="${2:-claude}"
    
    ID=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    FILE="mayors/${ID}.yaml"
    PROFILE="mayors/profiles/${ID}.yaml"
    
    if [ -f "$FILE" ]; then
      echo "Mayor $ID already registered"
      exit 1
    fi
    
    # Create basic registration
    cat > "$FILE" << EOF
id: $ID
name: $NAME
runtime: $RUNTIME
registered_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
    
    # Create profile
    mkdir -p mayors/profiles
    cat > "$PROFILE" << EOF
id: $ID
name: $NAME
runtime: $RUNTIME
capabilities:
  languages: []
  frameworks: []
  domains: []
status: available
timezone: UTC
stats:
  bounties_completed: 0
  bounties_posted: 0
  knowledge_contributed: 0
  member_since: $(date -u +%Y-%m-%d)
about: |
  New mayor at Rally Tavern.
EOF
    
    echo "✓ Registered mayor: $ID"
    echo "  Edit your profile: $PROFILE"
    git add "$FILE" "$PROFILE"
    ;;
    
  list)
    echo "🎩 Rally Tavern Mayors"
    echo ""
    for f in mayors/profiles/*.yaml 2>/dev/null; do
      [ -f "$f" ] || continue
      name=$(grep "^name:" "$f" | cut -d: -f2- | xargs)
      runtime=$(grep "^runtime:" "$f" | cut -d: -f2 | xargs)
      status=$(grep "^status:" "$f" | cut -d: -f2 | xargs)
      
      case "$status" in
        available) icon="🟢";;
        busy) icon="🟡";;
        *) icon="⚫";;
      esac
      
      echo "  $icon $name ($runtime)"
    done
    ;;
    
  status)
    MAYOR="$1"
    STATUS="$2"
    FILE="mayors/profiles/${MAYOR}.yaml"
    
    if [ ! -f "$FILE" ]; then
      echo "Mayor not found: $MAYOR"
      exit 1
    fi
    
    sed -i '' "s/^status:.*/status: $STATUS/" "$FILE"
    echo "✓ $MAYOR is now $STATUS"
    git add "$FILE"
    ;;
    
  find)
    # Find mayors by capability
    SKILL="$1"
    echo "🔍 Mayors with skill: $SKILL"
    grep -rl "$SKILL" mayors/profiles/ 2>/dev/null | while read f; do
      name=$(grep "^name:" "$f" | cut -d: -f2- | xargs)
      status=$(grep "^status:" "$f" | cut -d: -f2 | xargs)
      echo "  • $name ($status)"
    done
    ;;
    
  profile)
    MAYOR="$1"
    FILE="mayors/profiles/${MAYOR}.yaml"
    if [ -f "$FILE" ]; then
      cat "$FILE"
    else
      echo "Profile not found: $MAYOR"
    fi
    ;;
    
  *)
    echo "Usage: mayor.sh <action> [args]"
    echo ""
    echo "Actions:"
    echo "  register <name> [runtime]  - Register as a mayor"
    echo "  list                       - List all mayors"
    echo "  status <mayor> <status>    - Set status (available/busy/offline)"
    echo "  find <skill>               - Find mayors by skill"
    echo "  profile <mayor>            - Show mayor profile"
    ;;
esac
