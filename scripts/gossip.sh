#!/bin/bash
# Post or read gossip
# Usage: ./scripts/gossip.sh <topic> [intel]

TOPIC="$1"
INTEL="$2"

if [ -z "$INTEL" ]; then
  # Read gossip
  echo "📢 Gossip on: $TOPIC"
  for f in gossip/*.yaml; do
    [ -f "$f" ] || continue
    t=$(grep "^topic:" "$f" | cut -d: -f2 | xargs)
    [ "$t" = "$TOPIC" ] || continue
    intel=$(grep "^intel:" "$f" | cut -d: -f2- | xargs)
    by=$(grep "^posted_by:" "$f" | cut -d: -f2 | xargs)
    echo "  - $intel (via $by)"
  done
else
  # Post gossip
  MAYOR=$(ls mayors/*.yaml 2>/dev/null | head -1 | xargs -I{} basename {} .yaml)
  ID="gossip-$(openssl rand -hex 4)"
  FILE="gossip/${ID}.yaml"
  
  cat > "$FILE" << EOF
id: $ID
topic: $TOPIC
intel: $INTEL
posted_by: ${MAYOR:-anonymous}
posted_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
expires_at: $(date -u -v+7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "+7 days" +%Y-%m-%dT%H:%M:%SZ)
EOF
  
  echo "✓ Posted gossip on $TOPIC"
  git add "$FILE"
fi
