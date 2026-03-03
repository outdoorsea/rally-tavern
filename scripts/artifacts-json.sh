#!/bin/bash
# Rally Tavern Artifact Discovery Endpoint
# Machine-readable JSON output for Mayors and agents
#
# Usage: artifacts-json.sh [--tags TAG1,TAG2] [--type TYPE] [--trust MIN_TRUST]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="$ROOT_DIR/artifacts"

FILTER_TAGS=""
FILTER_TYPE=""
FILTER_TRUST=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --tags) FILTER_TAGS="$2"; shift 2;;
    --type) FILTER_TYPE="$2"; shift 2;;
    --trust) FILTER_TRUST="$2"; shift 2;;
    *) shift;;
  esac
done

command -v yq >/dev/null 2>&1 || { echo '{"error": "yq is required"}' >&2; exit 1; }

# Trust level ordering for minimum trust filter
trust_rank() {
  case "$1" in
    verified)     echo 3;;
    community)    echo 2;;
    experimental) echo 1;;
    *)            echo 0;;
  esac
}

min_trust_rank=0
if [ -n "$FILTER_TRUST" ]; then
  min_trust_rank=$(trust_rank "$FILTER_TRUST")
fi

# Collect artifacts
echo '{'
echo '  "artifacts": ['

count=0
for manifest in "$ARTIFACTS_DIR"/*/*/artifact.yaml; do
  [ -f "$manifest" ] || continue

  # Skip deprecated
  deprecated=$(yq -r '.deprecated // false' "$manifest" 2>/dev/null || echo "false")
  [ "$deprecated" = "true" ] && continue

  name=$(yq -r '.name // .metadata.id // ""' "$manifest")
  namespace=$(yq -r '.namespace // ""' "$manifest")
  version=$(yq -r '.version // .metadata.version // "0.0.0"' "$manifest")
  desc=$(yq -r '.description // .metadata.description // ""' "$manifest")
  artifact_type=$(yq -r '.spec.artifactType // "unknown"' "$manifest" 2>/dev/null || echo "unknown")
  trust=$(yq -r '.trust_tier // .trust.level // "experimental"' "$manifest")
  tags_json=$(yq -r '(.tags // .metadata.tags // []) | @json' "$manifest" 2>/dev/null || echo "[]")
  token_savings=$(yq -r '.scoring.tokenSavingsEstimate // 0' "$manifest" 2>/dev/null || echo "0")
  created_at=$(yq -r '.created_at // .provenance.createdAt // ""' "$manifest" 2>/dev/null || echo "")

  # --- Apply filters ---

  # Type filter
  if [ -n "$FILTER_TYPE" ] && [ "$artifact_type" != "$FILTER_TYPE" ]; then
    continue
  fi

  # Trust filter (minimum level)
  if [ $min_trust_rank -gt 0 ]; then
    this_rank=$(trust_rank "$trust")
    [ "$this_rank" -lt "$min_trust_rank" ] && continue
  fi

  # Tag filter (any match)
  if [ -n "$FILTER_TAGS" ]; then
    tags_text=$(yq -r '(.tags // .metadata.tags // []) | .[]' "$manifest" 2>/dev/null || echo "")
    match=0
    IFS=',' read -ra filter_tag_list <<< "$FILTER_TAGS"
    for ft in "${filter_tag_list[@]}"; do
      ft=$(echo "$ft" | xargs)
      if echo "$tags_text" | grep -qi "$ft"; then
        match=1
        break
      fi
    done
    [ $match -eq 0 ] && continue
  fi

  # --- Emit entry ---
  [ $count -gt 0 ] && echo ","

  cat <<ENTRY
    {
      "id": "${namespace}/${name}",
      "name": "$name",
      "namespace": "$namespace",
      "version": "$version",
      "artifactType": "$artifact_type",
      "description": "$desc",
      "tags": $tags_json,
      "trust": "$trust",
      "tokenSavingsEstimate": $token_savings,
      "createdAt": "$created_at"
    }
ENTRY

  count=$((count + 1))
done

echo ""
echo '  ],'
echo "  \"count\": $count,"
echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
echo '}'
