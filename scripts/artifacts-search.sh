#!/bin/bash
# Rally Tavern Artifact Search
# Ranked artifact discovery based on query terms
#
# Usage: artifacts-search.sh "fastapi google sso" [--limit 10]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="${ARTIFACT_DIR_OVERRIDE:-$ROOT_DIR/artifacts}"

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
  # Read token savings (supports both structured and flat formats)
  token_savings=$(yq -r '.scoring.tokenSavingsEstimate.estimatedSavingsTokens // null' "$manifest" 2>/dev/null)
  if [ "$token_savings" = "null" ] || [ -z "$token_savings" ]; then
    token_savings=$(yq -r '.scoring.tokenSavingsEstimate // 0' "$manifest" 2>/dev/null || echo "0")
    case "$token_savings" in *baselineTokens*|*{*) token_savings=0;; esac
  fi

  # Read usage metrics from .usage.jsonl
  artifact_dir=$(dirname "$manifest")
  usage_file="$artifact_dir/.usage.jsonl"
  use_count=0
  total_actual_saved=0
  if [ -f "$usage_file" ]; then
    while IFS= read -r uline; do
      [ -z "$uline" ] && continue
      use_count=$((use_count + 1))
      utokens=$(echo "$uline" | jq -r '.tokensSaved // 0' 2>/dev/null || echo "0")
      total_actual_saved=$((total_actual_saved + utokens))
    done < "$usage_file"
  fi

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

  # 3. Token savings bonus (actual > estimated)
  # Prefer actual usage data when available
  effective_savings=$token_savings
  if [ "$total_actual_saved" -gt 0 ] && [ "$use_count" -gt 0 ]; then
    effective_savings=$((total_actual_saved / use_count))
  fi
  if [ "$effective_savings" -gt 0 ] 2>/dev/null; then
    bonus=$((effective_savings / 10000))
    [ $bonus -gt 10 ] && bonus=10
    score=$((score + bonus))
  fi

  # 4. Use count bonus (more usage = more trusted, 2 points per use, cap 10)
  if [ "$use_count" -gt 0 ] 2>/dev/null; then
    use_bonus=$((use_count * 2))
    [ $use_bonus -gt 10 ] && use_bonus=10
    score=$((score + use_bonus))
  fi

  # Collect result with score for sorting
  tags_json=$(yq -r '(.tags // .metadata.tags // []) | @json' "$manifest" 2>/dev/null || echo "[]")

  results+=("$score|$namespace/$name|$version|$artifact_type|$trust|$token_savings|$desc|$tags_json|$use_count|$total_actual_saved")
done

# Sort by score descending
IFS=$'\n' sorted=($(printf '%s\n' "${results[@]}" | sort -t'|' -k1 -nr))
unset IFS

# Output JSON
echo "["
count=0
for entry in "${sorted[@]}"; do
  [ $count -ge "$LIMIT" ] && break

  IFS='|' read -r score id version atype trust savings desc tags use_count total_actual <<< "$entry"

  [ $count -gt 0 ] && echo ","

  # Calculate avg if we have actual usage
  avg_actual=0
  if [ "${use_count:-0}" -gt 0 ] 2>/dev/null && [ "${total_actual:-0}" -gt 0 ] 2>/dev/null; then
    avg_actual=$((total_actual / use_count))
  fi

  cat <<ENTRY
  {
    "id": "$id",
    "version": "$version",
    "artifactType": "$atype",
    "trust": "$trust",
    "tokenSavingsEstimate": $savings,
    "usage": {
      "useCount": ${use_count:-0},
      "totalTokensSaved": ${total_actual:-0},
      "avgTokensSaved": $avg_actual
    },
    "description": "$desc",
    "tags": $tags,
    "score": $score
  }
ENTRY

  count=$((count + 1))
done
echo ""
echo "]"
