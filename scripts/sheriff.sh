#!/bin/bash
# Sheriff commands for tavern moderation

ACTION="$1"
shift

# Check if user is a sheriff
SHERIFF_FILE="tavern/sheriffs.yaml"
CURRENT_USER=$(git config user.name | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

is_sheriff() {
  [ -f "$SHERIFF_FILE" ] && grep -q "$CURRENT_USER" "$SHERIFF_FILE"
}

case "$ACTION" in
  approve)
    FILE="$1"
    if [ ! -f "$FILE" ]; then
      echo "File not found: $FILE"
      exit 1
    fi
    
    echo "🤠 Sheriff approval for: $FILE"
    
    # Add approval metadata
    echo "" >> "$FILE"
    echo "# 🟢 SHERIFF APPROVED" >> "$FILE"
    echo "# approved_by: $CURRENT_USER" >> "$FILE"
    echo "# approved_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$FILE"
    
    echo "✓ Approved! Content is now 🟢 trusted."
    git add "$FILE"
    ;;
    
  flag)
    FILE="$1"
    REASON="$2"
    
    mkdir -p tavern/jail
    ID="flag-$(date +%Y%m%d)-$(openssl rand -hex 4)"
    
    cat > "tavern/jail/${ID}.yaml" << EOF
id: $ID
file: $FILE
flagged_by: $CURRENT_USER
flagged_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
reason: |
  $REASON
status: pending
EOF
    
    echo "🚨 Flagged: $FILE"
    echo "   Reason: $REASON"
    echo "   Flag ID: $ID"
    git add "tavern/jail/${ID}.yaml"
    ;;
    
  jail)
    echo "🚨 Flagged Content (The Jail)"
    echo ""
    for f in tavern/jail/*.yaml; do
      [ -f "$f" ] || continue
      file=$(grep "^file:" "$f" | cut -d: -f2- | xargs)
      reason=$(grep -A1 "^reason:" "$f" | tail -1 | xargs)
      status=$(grep "^status:" "$f" | cut -d: -f2 | xargs)
      echo "  [$status] $file"
      echo "     $reason"
    done
    [ ! "$(ls tavern/jail/*.yaml 2>/dev/null)" ] && echo "  (empty - all clear! 🎉)"
    ;;
    
  resolve)
    DISPUTE_ID="$1"
    RESOLUTION="$2"
    
    mkdir -p tavern/resolved
    
    cat > "tavern/resolved/${DISPUTE_ID}.yaml" << EOF
dispute: $DISPUTE_ID
resolved_by: $CURRENT_USER
resolved_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
resolution: |
  $RESOLUTION
EOF
    
    echo "✓ Dispute resolved: $DISPUTE_ID"
    git add "tavern/resolved/"
    ;;
    
  deputize)
    USER="$1"
    POWER="$2"
    
    mkdir -p tavern/deputies
    
    cat > "tavern/deputies/${USER}.yaml" << EOF
deputy: $USER
appointed_by: $CURRENT_USER
appointed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
powers: [$POWER]
EOF
    
    echo "🤠 Deputized: $USER"
    echo "   Powers: $POWER"
    git add "tavern/deputies/"
    ;;
    
  status)
    echo "🤠 Sheriff Status"
    echo ""
    echo "Sheriffs:"
    if [ -f "$SHERIFF_FILE" ]; then
      grep "name:" "$SHERIFF_FILE" | cut -d: -f2
    else
      echo "  (none appointed yet)"
    fi
    echo ""
    echo "Deputies:"
    for f in tavern/deputies/*.yaml; do
      [ -f "$f" ] || continue
      deputy=$(grep "^deputy:" "$f" | cut -d: -f2 | xargs)
      powers=$(grep "^powers:" "$f" | cut -d: -f2- | xargs)
      echo "  ⭐ $deputy - $powers"
    done
    [ ! "$(ls tavern/deputies/*.yaml 2>/dev/null)" ] && echo "  (none)"
    ;;
    
  *)
    echo "🤠 Sheriff Commands"
    echo ""
    echo "Usage: sheriff.sh <action> [args]"
    echo ""
    echo "Actions:"
    echo "  approve <file>              - Approve high-risk content"
    echo "  flag <file> <reason>        - Flag suspicious content"
    echo "  jail                        - View flagged content"
    echo "  resolve <id> <resolution>   - Resolve a dispute"
    echo "  deputize <user> <power>     - Grant limited powers"
    echo "  status                      - Show sheriffs and deputies"
    echo ""
    echo "Powers: security-review, quality-review, moderation"
    ;;
esac
