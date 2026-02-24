#!/bin/bash
# Post a bounty
# Usage: ./scripts/post.sh "Title" [--priority N] [--description "..."]

TITLE="$1"
shift

PRIORITY=3
DESCRIPTION=""
TAGS=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --priority|-p) PRIORITY="$2"; shift 2;;
    --description|-d) DESCRIPTION="$2"; shift 2;;
    --tags|-t) TAGS="$2"; shift 2;;
    *) shift;;
  esac
done

ID="bounty-$(openssl rand -hex 4)"
FILE="bounties/open/${ID}.yaml"

# Get current mayor
MAYOR=$(ls mayors/*.yaml 2>/dev/null | head -1 | xargs -I{} basename {} .yaml)
MAYOR="${MAYOR:-anonymous}"

cat > "$FILE" << EOF
id: $ID
title: $TITLE
description: $DESCRIPTION
priority: $PRIORITY
tags: [${TAGS}]
posted_by: $MAYOR
posted_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "✓ Posted bounty: $ID"
echo "  Title: $TITLE"
echo "  Priority: P$PRIORITY"
git add "$FILE"
