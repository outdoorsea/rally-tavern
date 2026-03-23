#!/bin/bash
# Rally Tavern Overseer Management

ACTION="$1"
shift

case "$ACTION" in
  register)
    NAME="$1"
    GITHUB="${2:-}"
    
    ID=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    FILE="overseers/profiles/${ID}.yaml"
    
    mkdir -p overseers/profiles
    
    cat > "$FILE" << EOF
id: $ID
name: $NAME
github: $GITHUB
registered_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
towns: []
projects: []
interests: []
timezone: UTC
status: active
EOF
    
    echo "✓ Registered overseer: $ID"
    echo "  Edit profile: $FILE"
    git add "$FILE"
    ;;
    
  list)
    echo "👤 Rally Tavern Overseers"
    echo ""
    for f in overseers/profiles/*.yaml; do
      [ -f "$f" ] || continue
      name=$(grep "^name:" "$f" | cut -d: -f2- | xargs)
      github=$(grep "^github:" "$f" | cut -d: -f2 | xargs)
      echo "  • $name (@$github)"
    done
    ;;
    
  towns)
    OVERSEER="$1"
    FILE="overseers/profiles/${OVERSEER}.yaml"
    if [ -f "$FILE" ]; then
      echo "Towns for $OVERSEER:"
      grep -A10 "^towns:" "$FILE" | grep "name:" | while read line; do
        echo "  • $(echo $line | cut -d: -f2 | xargs)"
      done
    fi
    ;;
    
  *)
    echo "Usage: overseer.sh <action> [args]"
    echo ""
    echo "Actions:"
    echo "  register <name> [github]  - Register as overseer"
    echo "  list                      - List all overseers"
    echo "  towns <overseer>          - Show overseer's towns"
    ;;
esac
