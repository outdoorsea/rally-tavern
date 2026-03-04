#!/bin/bash
# Mayor completes a bounty
# Usage: ./scripts/mayor-complete.sh <mayor-name> <bounty-id> [--summary "..."] [--artifact <id>@<version>] [--token-savings <number>] [--json]

MAYOR="$1"
BOUNTY_ID="$2"
shift 2

SUMMARY=""
JSON_OUTPUT=""
ARTIFACT=""
TOKEN_SAVINGS=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --summary|-s) SUMMARY="$2"; shift 2;;
    --artifact|-a) ARTIFACT="$2"; shift 2;;
    --token-savings|-t) TOKEN_SAVINGS="$2"; shift 2;;
    --json) JSON_OUTPUT="yes"; shift;;
    *) shift;;
  esac
done

CLAIMED_FILE="bounties/claimed/${BOUNTY_ID}.yaml"
DONE_FILE="bounties/done/${BOUNTY_ID}.yaml"

if [ ! -f "$CLAIMED_FILE" ]; then
  [ "$JSON_OUTPUT" ] && echo '{"success": false, "error": "not_claimed"}' || echo "❌ Not claimed: $BOUNTY_ID"
  exit 1
fi

# Verify it's claimed by this mayor
CLAIMED_BY=$(grep "^claimed_by:" "$CLAIMED_FILE" | cut -d: -f2 | xargs)
if [ "$CLAIMED_BY" != "$MAYOR" ]; then
  [ "$JSON_OUTPUT" ] && echo "{\"success\": false, \"error\": \"claimed_by_other\", \"claimed_by\": \"$CLAIMED_BY\"}" || echo "❌ Claimed by $CLAIMED_BY, not $MAYOR"
  exit 1
fi

mv "$CLAIMED_FILE" "$DONE_FILE"

# Append status block
{
  echo "status:"
  echo "  state: done"
  echo "  completedAt: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "  completedBy: $MAYOR"
  if [ -n "$ARTIFACT" ]; then
    # Parse artifact id and version from id@version format
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

[ -n "$SUMMARY" ] && echo "summary: |"$'\n'"  $SUMMARY" >> "$DONE_FILE"

git add bounties/

if [ "$JSON_OUTPUT" ]; then
  JSON_RESULT="{\"success\": true, \"bounty_id\": \"$BOUNTY_ID\", \"completed_by\": \"$MAYOR\""
  [ -n "$ARTIFACT" ] && JSON_RESULT="$JSON_RESULT, \"artifact\": \"$ARTIFACT\""
  [ -n "$TOKEN_SAVINGS" ] && JSON_RESULT="$JSON_RESULT, \"token_savings\": $TOKEN_SAVINGS"
  echo "$JSON_RESULT}"
else
  echo "✓ 🎩 Completed by $MAYOR: $BOUNTY_ID"
  [ -n "$ARTIFACT" ] && echo "  📦 Artifact: $ARTIFACT"
  [ -n "$TOKEN_SAVINGS" ] && echo "  💰 Token savings: $TOKEN_SAVINGS"
fi
