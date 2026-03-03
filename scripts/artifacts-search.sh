#!/bin/bash
# Rally Tavern Artifact Search
# Ranked artifact discovery based on query terms
#
# Usage: artifacts-search.sh "fastapi google sso" [--limit 10]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="$ROOT_DIR/artifacts"

QUERY=""
LIMIT=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --limit) LIMIT="$2"; shift 2;;
    *) QUERY="$QUERY $1"; shift;;
  esac
done

QUERY=$(echo "$QUERY" | xargs)  # trim

if [ -z "$QUERY" ]; then
  echo "Usage: artifacts-search.sh <query> [--limit N]" >&2
  exit 1
fi

command -v yq >/dev/null 2>&1 || { echo "❌ yq is required. Install: brew install yq" >&2; exit 1; }

# Split query into terms
IFS=' ' read -ra TERMS <<< "$QUERY"

# Score and collect results
results=()

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
  tags_raw=$(yq -r '(.tags // .metadata.tags // []) | .[]' "$manifest" 2>/dev/null || echo "")
  token_savings=$(yq -r '.scoring.tokenSavingsEstimate // 0' "$manifest" 2>/dev/null || echo "0")

  # Combine searchable text
  searchable="$name $desc $tags_raw $artifact_type $namespace"
  searchable_lower=$(echo "$searchable" | tr '[:upper:]' '[:lower:]')

  # --- Scoring ---
  score=0

  # 1. Tag/term match score (10 points per match)
  for term in "${TERMS[@]}"; do
    term_lower=$(echo "$term" | tr '[:upper:]' '[:lower:]')
    if echo "$searchable_lower" | grep -q "$term_lower"; then
      score=$((score + 10))
    fi
  done

  # Skip if no terms matched
  [ $score -eq 0 ] && continue

  # 2. Trust level bonus
  case "$trust" in
    verified)  score=$((score + 15));;
    community) score=$((score + 10));;
    experimental) score=$((score + 0));;
  esac

  # 3. Token savings bonus (normalized: 1 point per 10k tokens)
  if [ "$token_savings" -gt 0 ] 2>/dev/null; then
    bonus=$((token_savings / 10000))
    [ $bonus -gt 10 ] && bonus=10
    score=$((score + bonus))
  fi

  # Collect result with score for sorting
  tags_json=$(yq -r '(.tags // .metadata.tags // []) | @json' "$manifest" 2>/dev/null || echo "[]")

  results+=("$score|$namespace/$name|$version|$artifact_type|$trust|$token_savings|$desc|$tags_json")
done

# Sort by score descending
IFS=$'\n' sorted=($(printf '%s\n' "${results[@]}" | sort -t'|' -k1 -nr))
unset IFS

# Output JSON
echo "["
count=0
for entry in "${sorted[@]}"; do
  [ $count -ge "$LIMIT" ] && break

  IFS='|' read -r score id version atype trust savings desc tags <<< "$entry"

  [ $count -gt 0 ] && echo ","

  cat <<ENTRY
  {
    "id": "$id",
    "version": "$version",
    "artifactType": "$atype",
    "trust": "$trust",
    "tokenSavingsEstimate": $savings,
    "description": "$desc",
    "tags": $tags,
    "score": $score
  }
ENTRY

  count=$((count + 1))
done
echo ""
echo "]"
