#!/bin/bash
# Federated Artifact Index Generator
# Aggregates all rig .index.json files into artifacts/federated-index.json
#
# Usage: artifact-federated-index.sh [--output PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GT_ROOT="${GT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
OUTPUT="${1:-$ROOT_DIR/artifacts/federated-index.json}"

command -v jq >/dev/null 2>&1 || { echo "jq is required. Install: brew install jq" >&2; exit 1; }

timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Start building the JSON
rigs_json="{"
rig_count=0
total_artifacts=0

for rig_dir in "$GT_ROOT"/*/; do
  rig_name=$(basename "$rig_dir")

  # Skip non-rig directories
  [[ "$rig_name" == "mayor" || "$rig_name" == "docs" || "$rig_name" == ".*" ]] && continue

  for crew_dir in "$rig_dir"crew/*/; do
    [ -d "$crew_dir" ] || continue
    worker=$(basename "$crew_dir")
    index_file="$crew_dir/artifacts/.index.json"

    if [ -f "$index_file" ]; then
      artifact_count=$(jq 'length' "$index_file" 2>/dev/null || echo "0")
      artifacts_content=$(jq '.' "$index_file" 2>/dev/null || echo "[]")
    else
      artifact_count=0
      artifacts_content="[]"
    fi

    [ $rig_count -gt 0 ] && rigs_json="$rigs_json,"
    rigs_json="$rigs_json
    \"$rig_name\": {
      \"worker\": \"$worker\",
      \"count\": $artifact_count,
      \"artifacts\": $artifacts_content
    }"

    total_artifacts=$((total_artifacts + artifact_count))
    rig_count=$((rig_count + 1))
  done
done

rigs_json="$rigs_json
  }"

# Write the final JSON
cat > "$OUTPUT" <<EOF
{
  "generated_at": "$timestamp",
  "rigs": $rigs_json,
  "total": $total_artifacts
}
EOF

# Pretty-print with jq if available
if command -v jq >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq '.' "$OUTPUT" > "$tmp" && mv "$tmp" "$OUTPUT"
fi

echo "Federated index generated: $OUTPUT ($total_artifacts artifacts across $rig_count rigs)"
