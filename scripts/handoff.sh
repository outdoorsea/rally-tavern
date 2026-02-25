#!/bin/bash
# Hand off work to another overseer

TO="$1"
SUBJECT="$2"
shift 2

CONTEXT=""
FILES=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --context|-c) CONTEXT="$2"; shift 2;;
    --files|-f) FILES="$2"; shift 2;;
    *) shift;;
  esac
done

if [ -z "$TO" ] || [ -z "$SUBJECT" ]; then
  echo "Usage: handoff.sh <to-overseer> <subject> [--context '...'] [--files 'a,b,c']"
  exit 1
fi

FROM=$(ls overseers/profiles/*.yaml 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.yaml//')
FROM="${FROM:-$(git config user.name | tr ' ' '-' | tr '[:upper:]' '[:lower:]')}"

mkdir -p coordination/handoffs
ID="handoff-$(date +%Y%m%d)-$(openssl rand -hex 4)"
FILE="coordination/handoffs/${ID}.yaml"

cat > "$FILE" << EOF
id: $ID
from: $FROM
to: $TO
subject: $SUBJECT
context: |
  $CONTEXT
files: [${FILES}]
created_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
acknowledged: false
EOF

echo "✓ Handoff created: $FROM → $TO"
echo "  Subject: $SUBJECT"
git add "$FILE"
