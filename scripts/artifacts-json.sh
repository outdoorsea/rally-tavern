#!/bin/bash
# Rally Tavern Artifact Discovery Endpoint
# Machine-readable JSON output for Mayors and agents
#
# Usage: artifacts-json.sh [--tags TAG1,TAG2] [--type TYPE] [--trust MIN_TRUST]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="${ARTIFACT_DIR_OVERRIDE:-$ROOT_DIR/artifacts}"

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
  # Read token savings (supports both structured and flat formats)
  token_savings=$(yq -r '.scoring.tokenSavingsEstimate.estimatedSavingsTokens // null' "$manifest" 2>/dev/null)
  if [ "$token_savings" = "null" ] || [ -z "$token_savings" ]; then
    token_savings=$(yq -r '.scoring.tokenSavingsEstimate // 0' "$manifest" 2>/dev/null || echo "0")
    case "$token_savings" in *baselineTokens*|*{*) token_savings=0;; esac
  fi
  created_at=$(yq -r '.created_at // .provenance.createdAt // ""' "$manifest" 2>/dev/null || echo "")

  # Read usage metrics
  artifact_dir=$(dirname "$manifest")
  usage_file="$artifact_dir/.usage.jsonl"
  use_count=0
  total_actual_saved=0
  avg_saved=0
  if [ -f "$usage_file" ]; then
    while IFS= read -r uline; do
      [ -z "$uline" ] && continue
      use_count=$((use_count + 1))
      utokens=$(echo "$uline" | jq -r '.tokensSaved // 0' 2>/dev/null || echo "0")
      total_actual_saved=$((total_actual_saved + utokens))
    done < "$usage_file"
    if [ $use_count -gt 0 ]; then
      avg_saved=$((total_actual_saved / use_count))
    fi
  fi

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
      "usage": {
        "useCount": $use_count,
        "totalTokensSaved": $total_actual_saved,
        "avgTokensSaved": $avg_saved
      },
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
