#!/bin/bash
# Complete a bounty
# Usage: ./scripts/complete.sh <bounty-id> [--summary "..."] [--artifact <id>@<version>] [--token-savings <number>]

BOUNTY_ID="$1"
shift
SUMMARY=""
ARTIFACT=""
TOKEN_SAVINGS=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --summary|-s) SUMMARY="$2"; shift 2;;
    --artifact|-a) ARTIFACT="$2"; shift 2;;
    --token-savings|-t) TOKEN_SAVINGS="$2"; shift 2;;
    *) shift;;
  esac
done

CLAIMED_FILE="bounties/claimed/${BOUNTY_ID}.yaml"
DONE_FILE="bounties/done/${BOUNTY_ID}.yaml"

if [ ! -f "$CLAIMED_FILE" ]; then
  echo "Bounty $BOUNTY_ID not found in claimed/"
  exit 1
fi

mv "$CLAIMED_FILE" "$DONE_FILE"

# Append status block
{
  echo "status:"
  echo "  state: done"
  echo "  completedAt: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [ -n "$ARTIFACT" ]; then
    ARTIFACT_ID="${ARTIFACT%@*}"
    ARTIFACT_VERSION="${ARTIFACT#*@}"
    echo "  resolvedWithArtifactId: $ARTIFACT_ID"
    if [ "$ARTIFACT_VERSION" != "$ARTIFACT" ]; then
      echo "  resolvedWithVersion: $ARTIFACT_VERSION"
    fi
  fi
  if [ -n "$TOKEN_SAVINGS" ]; then
    echo "  tokenSavingsActual: $TOKEN_SAVINGS"
  fi
} >> "$DONE_FILE"

[ -n "$SUMMARY" ] && echo "result: $SUMMARY" >> "$DONE_FILE"

echo "✓ Completed: $BOUNTY_ID"
[ -n "$ARTIFACT" ] && echo "  📦 Artifact: $ARTIFACT"
[ -n "$TOKEN_SAVINGS" ] && echo "  💰 Token savings: $TOKEN_SAVINGS"
git add bounties/
