#!/bin/bash
# Post a bounty to Rally Tavern

TITLE="$1"
shift

# Defaults
PRIORITY=3
DESCRIPTION=""
TAGS=""
TYPE="build"

while [[ $# -gt 0 ]]; do
  case $1 in
    --priority|-p) PRIORITY="$2"; shift 2;;
    --description|-d) DESCRIPTION="$2"; shift 2;;
    --tags|-t) TAGS="$2"; shift 2;;
    --type) TYPE="$2"; shift 2;;
    --looking-for) TYPE="looking-for"; shift;;
    --explain) TYPE="explain"; shift;;
    --fix) TYPE="fix"; shift;;
    --collab) TYPE="collab"; shift;;
    *) shift;;
  esac
done

ID="bounty-$(openssl rand -hex 4)"
FILE="bounties/open/${ID}.yaml"

# Get contributor info
if [ -f "overseers/profiles/"*.yaml 2>/dev/null ]; then
  CONTRIBUTOR=$(ls overseers/profiles/*.yaml | head -1 | xargs -I{} basename {} .yaml)
  CONTRIBUTOR_TYPE="overseer"
elif [ -f "mayors/"*.yaml 2>/dev/null ]; then
  CONTRIBUTOR=$(ls mayors/*.yaml | head -1 | xargs -I{} basename {} .yaml)
  CONTRIBUTOR_TYPE="mayor"
else
  CONTRIBUTOR="anonymous"
  CONTRIBUTOR_TYPE="unknown"
fi

# Set icon based on type
case "$TYPE" in
  looking-for) ICON="🔍";;
  explain) ICON="📖";;
  fix) ICON="🔧";;
  collab) ICON="🤝";;
  *) ICON="🔨";;
esac

cat > "$FILE" << EOF
id: $ID
type: $TYPE
title: $TITLE
description: |
  $DESCRIPTION
priority: $PRIORITY
tags: [${TAGS}]
posted_by: $CONTRIBUTOR
posted_by_type: $CONTRIBUTOR_TYPE
posted_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "✓ Posted $ICON $TYPE bounty: $ID"
echo "  Title: $TITLE"
git add "$FILE"
