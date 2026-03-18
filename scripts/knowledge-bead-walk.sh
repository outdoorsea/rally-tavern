#!/bin/bash
# Knowledge Bead Walk — Graph-aware knowledge discovery via bead dependencies
#
# Given a bead ID, walks the dependency graph (depth 2) to find contextually
# adjacent beads, then extracts knowledge entry IDs from their labels
# (knowledge:<entry-id>) and source_beads backlinks.
#
# Usage:
#   knowledge-bead-walk.sh <bead-id>
#   knowledge-bead-walk.sh <bead-id> --depth 3
#   knowledge-bead-walk.sh <bead-id> --format ids     # Just knowledge entry IDs
#   knowledge-bead-walk.sh <bead-id> --format json    # Full JSON output
#
# Output (default: ids):
#   One knowledge entry ID per line, deduplicated, ordered by graph distance.
#
# Graph walk resolves: relates_to, blocks/blocked_by, parent/child (all directions)

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

BEAD_ID=""
MAX_DEPTH=2
FORMAT="ids"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --depth)    MAX_DEPTH="${2:-2}"; shift 2;;
    --format)   FORMAT="${2:-ids}"; shift 2;;
    --help|-h)
      echo "Knowledge Bead Walk — Graph-aware knowledge discovery"
      echo ""
      echo "Usage: knowledge-bead-walk.sh <bead-id> [options]"
      echo ""
      echo "Options:"
      echo "  --depth <n>     Max graph traversal depth (default: 2)"
      echo "  --format <fmt>  Output format: ids (default), json"
      echo ""
      echo "Walks the bead dependency graph in both directions, collecting"
      echo "knowledge entry IDs from knowledge:<id> labels and source_beads"
      echo "backlinks on adjacent beads."
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      exit 1
      ;;
    *)
      if [[ -z "$BEAD_ID" ]]; then
        BEAD_ID="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$BEAD_ID" ]]; then
  log_error "Bead ID is required"
  exit 1
fi

if ! command -v bd &>/dev/null; then
  log_error "bd command not available"
  exit 1
fi

# --- Walk the dependency graph ---
# Use bd dep tree --direction=both --json to get all connected beads up to depth

graph_json=$(bd dep tree "$BEAD_ID" --direction=both --json --max-depth "$MAX_DEPTH" 2>/dev/null) || {
  log_error "Failed to walk dependency graph for $BEAD_ID"
  exit 1
}

# Extract bead IDs and their depths from graph JSON
# Output: depth|bead_id pairs
bead_ids_with_depth=$(echo "$graph_json" | python3 -c "
import json, sys

data = json.load(sys.stdin)
for node in data:
    bid = node.get('id', '')
    depth = node.get('depth', 0)
    if bid:
        print(f'{depth}|{bid}')
" 2>/dev/null) || {
  log_error "Failed to parse graph JSON"
  exit 1
}

if [[ -z "$bead_ids_with_depth" ]]; then
  # No graph nodes found
  exit 0
fi

# --- Also collect relates_to links (not always in dep tree) ---
# bd dep list handles relates_to separately
relates_json=$(bd dep list "$BEAD_ID" --json -t relates_to 2>/dev/null) || true
if [[ -n "$relates_json" ]] && [[ "$relates_json" != "[]" ]]; then
  relates_ids=$(echo "$relates_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for node in data:
    bid = node.get('id', '')
    if bid:
        print(f'1|{bid}')
" 2>/dev/null) || true
  if [[ -n "$relates_ids" ]]; then
    bead_ids_with_depth=$(printf '%s\n%s' "$bead_ids_with_depth" "$relates_ids")
  fi
fi

# Also check reverse relates_to
relates_up_json=$(bd dep list "$BEAD_ID" --direction=up --json -t relates_to 2>/dev/null) || true
if [[ -n "$relates_up_json" ]] && [[ "$relates_up_json" != "[]" ]]; then
  relates_up_ids=$(echo "$relates_up_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for node in data:
    bid = node.get('id', '')
    if bid:
        print(f'1|{bid}')
" 2>/dev/null) || true
  if [[ -n "$relates_up_ids" ]]; then
    bead_ids_with_depth=$(printf '%s\n%s' "$bead_ids_with_depth" "$relates_up_ids")
  fi
fi

# --- Collect knowledge IDs from labels and source_beads ---
# For each bead in the graph, check for knowledge:<id> labels

RESULT_FILE=$(mktemp)
trap "rm -f '$RESULT_FILE'" EXIT

while IFS='|' read -r depth bead_id; do
  [[ -z "$bead_id" ]] && continue

  # Check labels for knowledge:<entry-id> pattern
  labels=$(bd label list "$bead_id" --json 2>/dev/null) || continue

  if [[ -n "$labels" ]] && [[ "$labels" != "[]" ]]; then
    echo "$labels" | python3 -c "
import json, sys
depth = $depth
data = json.load(sys.stdin)
for label in data:
    name = label if isinstance(label, str) else label.get('name', '')
    if name.startswith('knowledge:'):
        kid = name[len('knowledge:'):]
        if kid:
            print(f'{depth}|{kid}')
" 2>/dev/null >> "$RESULT_FILE" || true
  fi
done <<< "$bead_ids_with_depth"

# --- Also scan knowledge entries for source_beads backlinking to graph beads ---
KNOWLEDGE_DIR="$TAVERN_ROOT/knowledge"

if [[ -d "$KNOWLEDGE_DIR" ]]; then
  # Collect all graph bead IDs for matching
  all_bead_ids=$(echo "$bead_ids_with_depth" | cut -d'|' -f2 | sort -u)

  while IFS= read -r kfile; do
    [[ -z "$kfile" ]] && continue
    content=$(cat "$kfile" 2>/dev/null) || continue

    # Check for source_beads field
    source_beads_line=$(echo "$content" | grep "^source_beads:" | head -1 || true)
    [[ -z "$source_beads_line" ]] && continue

    # Extract knowledge entry ID
    entry_id=$(echo "$content" | grep "^id:" | head -1 | cut -d: -f2- | xargs)
    [[ -z "$entry_id" ]] && continue

    # Check if any graph bead is in source_beads
    while IFS= read -r bid; do
      [[ -z "$bid" ]] && continue
      if echo "$source_beads_line" | grep -q "$bid"; then
        # Find the depth for this bead
        bead_depth=$(echo "$bead_ids_with_depth" | grep "|${bid}$" | head -1 | cut -d'|' -f1)
        bead_depth="${bead_depth:-1}"
        echo "${bead_depth}|${entry_id}" >> "$RESULT_FILE"
        break  # Only count once per knowledge entry
      fi
    done <<< "$all_bead_ids"
  done < <(find "$KNOWLEDGE_DIR" -name "*.yaml" -type f 2>/dev/null)
fi

# --- Also check snapshot for source_beads ---
for candidate in \
  "$TAVERN_ROOT/knowledge/snapshot.json" \
  "${GT_ROOT_DIR:-$TAVERN_ROOT/..}/.cache/rally-knowledge-snapshot.json"; do
  if [[ -f "$candidate" ]]; then
    all_bead_ids_json=$(echo "$bead_ids_with_depth" | python3 -c "
import sys
ids = {}
for line in sys.stdin:
    line = line.strip()
    if '|' in line:
        d, bid = line.split('|', 1)
        if bid not in ids:
            ids[bid] = int(d)
import json
print(json.dumps(ids))
" 2>/dev/null)

    python3 -c "
import json, sys

snapshot = json.load(open('$candidate'))
bead_depths = json.loads('$all_bead_ids_json')

for entry in snapshot.get('entries', []):
    source_beads = entry.get('source_beads', [])
    if not source_beads:
        continue
    entry_id = entry.get('id', '')
    if not entry_id:
        continue
    for sb in source_beads:
        if sb in bead_depths:
            print(f'{bead_depths[sb]}|{entry_id}')
            break
" 2>/dev/null >> "$RESULT_FILE" || true
    break
  fi
done

# --- Deduplicate and output ---

if [[ ! -s "$RESULT_FILE" ]]; then
  if [[ "$FORMAT" == "json" ]]; then
    echo "[]"
  fi
  exit 0
fi

case "$FORMAT" in
  ids)
    # Sort by depth (closer = more relevant), deduplicate by knowledge ID
    sort -t'|' -k1 -n "$RESULT_FILE" | awk -F'|' '!seen[$2]++ { print $2 }'
    ;;

  json)
    sort -t'|' -k1 -n "$RESULT_FILE" | awk -F'|' '!seen[$2]++ { print $1 "|" $2 }' | python3 -c "
import json, sys

results = []
for line in sys.stdin:
    line = line.strip()
    if '|' in line:
        depth, kid = line.split('|', 1)
        results.append({'knowledge_id': kid, 'graph_distance': int(depth)})

print(json.dumps(results, indent=2))
" 2>/dev/null
    ;;

  *)
    log_error "Unknown format: $FORMAT"
    exit 1
    ;;
esac
