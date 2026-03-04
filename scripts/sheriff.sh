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
    
  approve-artifact)
    ARTIFACT_ID="$1"
    [ -z "$ARTIFACT_ID" ] && echo "Usage: sheriff.sh approve-artifact <namespace/name>" && exit 1

    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    ARTIFACTS_DIR="${ARTIFACT_DIR_OVERRIDE:-$ROOT_DIR/artifacts}"
    ARTIFACT_DIR="$ARTIFACTS_DIR/$ARTIFACT_ID"
    MANIFEST="$ARTIFACT_DIR/artifact.yaml"

    [ ! -d "$ARTIFACT_DIR" ] && echo "Artifact not found: $ARTIFACT_ID" && exit 1
    [ ! -f "$MANIFEST" ] && echo "No artifact.yaml in: $ARTIFACT_DIR" && exit 1

    if ! command -v yq >/dev/null 2>&1; then
      echo "❌ yq is required. Install: brew install yq"
      exit 1
    fi

    CURRENT_TRUST=$(yq -r '.trust_tier // .trust.level // "experimental"' "$MANIFEST")
    NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    echo "🤠 Sheriff artifact approval: $ARTIFACT_ID"
    echo "   Current trust: $CURRENT_TRUST"

    # Determine promotion target
    case "$CURRENT_TRUST" in
      experimental|unverified)
        # Check automated promotion criteria for community
        SCAN_STATUS=$(yq -r '.trust.security.scanners[0].status // .trust.securityScans.status // "pending"' "$MANIFEST")

        if [ "$SCAN_STATUS" != "passed" ] && [ "$SCAN_STATUS" != "pass" ]; then
          echo "⚠️  Security scan not passed (status: $SCAN_STATUS)"
          echo "   Run: security.sh scan-artifact $ARTIFACT_ID"
          echo "   Sheriff can override with: sheriff.sh approve-artifact $ARTIFACT_ID --force"
          # Check for --force flag
          if [ "$2" != "--force" ]; then
            exit 1
          fi
          echo "   ⚡ Force override applied"
        fi

        NEW_TRUST="community"
        ;;
      community|community-verified)
        NEW_TRUST="verified"
        ;;
      verified|sheriff-approved)
        echo "✅ Artifact is already at highest trust level"
        exit 0
        ;;
      *)
        NEW_TRUST="community"
        ;;
    esac

    # Update trust level (both field locations for compatibility)
    yq -i ".trust_tier = \"$NEW_TRUST\"" "$MANIFEST" 2>/dev/null || true
    yq -i ".trust.level = \"$NEW_TRUST\"" "$MANIFEST"

    # Record approval
    yq -i ".trust.approvals = (.trust.approvals // []) + [{\"approved_by\": \"$CURRENT_USER\", \"approved_at\": \"$NOW\", \"from\": \"$CURRENT_TRUST\", \"to\": \"$NEW_TRUST\"}]" "$MANIFEST"

    # Update provenance timestamp
    yq -i ".provenance.updatedAt = \"$NOW\"" "$MANIFEST" 2>/dev/null || true

    git add "$MANIFEST"

    echo "✓ Promoted: $CURRENT_TRUST → $NEW_TRUST"
    echo "   Approved by: $CURRENT_USER"
    ;;

  flag-artifact)
    ARTIFACT_ID="$1"
    shift || true
    REASON=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        --reason) REASON="$2"; shift 2;;
        *) REASON="$1"; shift;;
      esac
    done

    [ -z "$ARTIFACT_ID" ] && echo "Usage: sheriff.sh flag-artifact <namespace/name> --reason \"...\"" && exit 1
    [ -z "$REASON" ] && echo "Usage: sheriff.sh flag-artifact <namespace/name> --reason \"...\"" && exit 1

    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    ARTIFACTS_DIR="${ARTIFACT_DIR_OVERRIDE:-$ROOT_DIR/artifacts}"
    ARTIFACT_DIR="$ARTIFACTS_DIR/$ARTIFACT_ID"
    MANIFEST="$ARTIFACT_DIR/artifact.yaml"

    [ ! -d "$ARTIFACT_DIR" ] && echo "Artifact not found: $ARTIFACT_ID" && exit 1
    [ ! -f "$MANIFEST" ] && echo "No artifact.yaml in: $ARTIFACT_DIR" && exit 1

    mkdir -p tavern/jail
    ID="flag-$(date +%Y%m%d)-$(openssl rand -hex 4)"

    cat > "tavern/jail/${ID}.yaml" << EOF
id: $ID
artifact: $ARTIFACT_ID
flagged_by: $CURRENT_USER
flagged_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
reason: |
  $REASON
status: pending
EOF

    # Demote artifact trust to unverified if yq is available
    if command -v yq >/dev/null 2>&1; then
      PREV_TRUST=$(yq -r '.trust_tier // .trust.level // "experimental"' "$MANIFEST")
      yq -i ".trust_tier = \"experimental\"" "$MANIFEST" 2>/dev/null || true
      yq -i ".trust.level = \"experimental\"" "$MANIFEST"
      yq -i ".trust.flags = (.trust.flags // []) + [{\"flag_id\": \"$ID\", \"flagged_by\": \"$CURRENT_USER\", \"flagged_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"reason\": \"$REASON\", \"previous_trust\": \"$PREV_TRUST\"}]" "$MANIFEST"
      git add "$MANIFEST"
    fi

    echo "🚨 Flagged artifact: $ARTIFACT_ID"
    echo "   Reason: $REASON"
    echo "   Flag ID: $ID"
    echo "   Trust demoted to: experimental"
    git add "tavern/jail/${ID}.yaml"
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
    echo "  approve <file>                            - Approve high-risk content"
    echo "  approve-artifact <namespace/name>         - Approve and promote artifact trust"
    echo "  flag <file> <reason>                      - Flag suspicious content"
    echo "  flag-artifact <id> --reason \"...\"         - Flag artifact and demote trust"
    echo "  jail                                      - View flagged content"
    echo "  resolve <id> <resolution>                 - Resolve a dispute"
    echo "  deputize <user> <power>                   - Grant limited powers"
    echo "  status                                    - Show sheriffs and deputies"
    echo ""
    echo "Powers: security-review, quality-review, moderation"
    ;;
esac
