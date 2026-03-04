#!/bin/bash
# Federated Artifact Search
# Searches artifacts across all Gas Town rigs
#
# Usage: artifact-federated-search.sh "auth sso" [--limit 10] [--rig NAME]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GT_ROOT="${GT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

QUERY=""
LIMIT=10
FILTER_RIG=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --limit) LIMIT="$2"; shift 2;;
    --rig) FILTER_RIG="$2"; shift 2;;
    *) QUERY="$QUERY $1"; shift;;
  esac
done

QUERY=$(echo "$QUERY" | xargs)  # trim

if [ -z "$QUERY" ]; then
  echo "Usage: artifact-federated-search.sh <query> [--limit N] [--rig NAME]" >&2
  exit 1
fi

command -v yq >/dev/null 2>&1 || { echo '{"error": "yq is required"}' >&2; exit 1; }

# Split query into terms
IFS=' ' read -ra TERMS <<< "$QUERY"

# Score and collect results
results=()

# Walk all rigs looking for crew worker artifact directories
for rig_dir in "$GT_ROOT"/*/; do
  rig_name=$(basename "$rig_dir")

  # Skip non-rig directories
  [[ "$rig_name" == "mayor" || "$rig_name" == "docs" || "$rig_name" == ".*" ]] && continue

  # Apply rig filter if specified
  [ -n "$FILTER_RIG" ] && [ "$rig_name" != "$FILTER_RIG" ] && continue

  # Find crew worker artifacts dirs
  for artifacts_dir in "$rig_dir"crew/*/artifacts; do
    [ -d "$artifacts_dir" ] || continue
    worker=$(basename "$(dirname "$artifacts_dir")")

    for manifest in "$artifacts_dir"/*/*/artifact.yaml; do
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

      for term in "${TERMS[@]}"; do
        term_lower=$(echo "$term" | tr '[:upper:]' '[:lower:]')
        if echo "$searchable_lower" | grep -q "$term_lower"; then
          score=$((score + 10))
        fi
      done

      # Skip if no terms matched
      [ $score -eq 0 ] && continue

      # Trust level bonus
      case "$trust" in
        verified)  score=$((score + 15));;
        community) score=$((score + 10));;
      esac

      # Token savings bonus
      if [ "$token_savings" -gt 0 ] 2>/dev/null; then
        bonus=$((token_savings / 10000))
        [ $bonus -gt 10 ] && bonus=10
        score=$((score + bonus))
      fi

      tags_json=$(yq -r '(.tags // .metadata.tags // []) | @json' "$manifest" 2>/dev/null || echo "[]")

      results+=("$score|$namespace/$name|$version|$artifact_type|$trust|$token_savings|$desc|$tags_json|$rig_name|$worker")
    done
  done
done

if [ ${#results[@]} -eq 0 ]; then
  echo '[]'
  exit 0
fi

# Sort by score descending
IFS=$'\n' sorted=($(printf '%s\n' "${results[@]}" | sort -t'|' -k1 -nr))
unset IFS

# Output JSON
echo "["
count=0
for entry in "${sorted[@]}"; do
  [ $count -ge "$LIMIT" ] && break

  IFS='|' read -r score id version atype trust savings desc tags source_rig source_worker <<< "$entry"

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
    "score": $score,
    "source_rig": "$source_rig",
    "source_worker": "$source_worker"
  }
ENTRY

  count=$((count + 1))
done
echo ""
echo "]"
