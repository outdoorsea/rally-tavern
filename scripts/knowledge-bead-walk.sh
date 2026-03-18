#!/usr/bin/env bash
# Knowledge Bead Walk — Walk the bead dependency graph to find contextually
# adjacent knowledge entries.
#
# Given a bead ID, walks the dependency graph (relates_to, blocks/blocked_by,
# parent/child) to depth 2, collecting tags, labels, and titles from connected
# beads. Outputs a structured summary that knowledge-push.sh can use for
# graph-aware ranking.
#
# Usage:
#   knowledge-bead-walk.sh <bead-id>
#   knowledge-bead-walk.sh <bead-id> --depth 3
#   knowledge-bead-walk.sh <bead-id> --format json
#   knowledge-bead-walk.sh <bead-id> --format tags
#
# Output formats:
#   json (default) — JSON object with graph-collected tags, titles, and source_beads
#   tags           — Newline-separated list of unique tags from graph neighbors

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

BEAD_ID=""
DEPTH=2
FORMAT="json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --depth)  DEPTH="${2:-2}"; shift 2;;
    --format) FORMAT="${2:-json}"; shift 2;;
    --help|-h)
      echo "Knowledge Bead Walk — Walk bead dependency graph for knowledge context"
      echo ""
      echo "Usage: knowledge-bead-walk.sh <bead-id> [options]"
      echo ""
      echo "Options:"
      echo "  --depth <n>    Walk depth (default: 2)"
      echo "  --format <fmt> Output format: json (default), tags"
      echo ""
      echo "Walks relates_to, blocks/blocked_by, parent/child edges to collect"
      echo "contextual information from neighboring beads."
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
  log_error "bd command not found"
  exit 1
fi

# --- Graph walk using temp files (bash 3.2 compatible — no associative arrays) ---

VISITED_FILE=$(mktemp)
GRAPH_FILE=$(mktemp)
TAGS_FILE=$(mktemp)
SOURCE_BEADS_FILE=$(mktemp)
trap "rm -f '$VISITED_FILE' '$GRAPH_FILE' '$TAGS_FILE' '$SOURCE_BEADS_FILE'" EXIT

# Check if a bead has been visited
is_visited() {
  grep -qx "$1" "$VISITED_FILE" 2>/dev/null
}

mark_visited() {
  echo "$1" >> "$VISITED_FILE"
}

# Collect info from a single bead
collect_bead_info() {
  local bead_id="$1" distance="$2"

  is_visited "$bead_id" && return
  mark_visited "$bead_id"

  local bead_json
  bead_json=$(bd show "$bead_id" --json 2>/dev/null) || return

  # Use python3 to extract all fields at once, piping JSON via stdin
  echo "$bead_json" | python3 -c "
import json, sys
bead_id, distance = sys.argv[1], sys.argv[2]
prefix = 'knowledge:'
data = json.load(sys.stdin)
if isinstance(data, list) and data:
    data = data[0]
title = data.get('title', '')
labels = data.get('labels', [])
if title:
    print('TITLE|' + title)
for label in labels:
    print('LABEL|' + label)
    if label.startswith(prefix):
        print('SOURCE_BEAD|' + label[len(prefix):])
print('GRAPH|' + bead_id + '|' + distance + '|' + title)
" "$bead_id" "$distance" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      TITLE\|*)   echo "${line#TITLE|}" >> "$GRAPH_FILE.titles" ;;
      LABEL\|*)   echo "${line#LABEL|}" >> "$TAGS_FILE" ;;
      SOURCE_BEAD\|*) echo "${line#SOURCE_BEAD|}" >> "$SOURCE_BEADS_FILE" ;;
      GRAPH\|*)   echo "${line#GRAPH|}" >> "$GRAPH_FILE" ;;
    esac
  done
}

# Get neighbors of a bead (dependencies + dependents)
get_neighbors() {
  local bead_id="$1"

  # Dependencies (what this bead depends on) — skip ephemeral wisps
  bd dep list "$bead_id" --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for d in data:
    dep_id = d.get('id', '')
    if dep_id and not dep_id.startswith('rt-wisp-'):
        print(dep_id)
" 2>/dev/null || true

  # Dependents (what depends on this bead) — skip ephemeral wisps
  bd dep list "$bead_id" --direction=up --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for d in data:
    dep_id = d.get('id', '')
    if dep_id and not dep_id.startswith('rt-wisp-'):
        print(dep_id)
" 2>/dev/null || true
}

# BFS walk using temp files for level queues
CURRENT_LEVEL_FILE=$(mktemp)
NEXT_LEVEL_FILE=$(mktemp)
trap "rm -f '$VISITED_FILE' '$GRAPH_FILE' '$GRAPH_FILE.titles' '$TAGS_FILE' '$SOURCE_BEADS_FILE' '$CURRENT_LEVEL_FILE' '$NEXT_LEVEL_FILE'" EXIT

echo "$BEAD_ID" > "$CURRENT_LEVEL_FILE"
touch "$GRAPH_FILE" "$GRAPH_FILE.titles" "$TAGS_FILE" "$SOURCE_BEADS_FILE"

current_depth=0
while [[ $current_depth -le $DEPTH ]] && [[ -s "$CURRENT_LEVEL_FILE" ]]; do
  > "$NEXT_LEVEL_FILE"

  while IFS= read -r bead_id; do
    [[ -z "$bead_id" ]] && continue
    collect_bead_info "$bead_id" "$current_depth"

    if [[ $current_depth -lt $DEPTH ]]; then
      neighbors=$(get_neighbors "$bead_id") || true
      while IFS= read -r neighbor; do
        [[ -z "$neighbor" ]] && continue
        is_visited "$neighbor" && continue
        echo "$neighbor" >> "$NEXT_LEVEL_FILE"
      done <<< "$neighbors"
    fi
  done < "$CURRENT_LEVEL_FILE"

  # Deduplicate next level
  if [[ -s "$NEXT_LEVEL_FILE" ]]; then
    sort -u "$NEXT_LEVEL_FILE" > "${NEXT_LEVEL_FILE}.tmp"
    mv "${NEXT_LEVEL_FILE}.tmp" "$NEXT_LEVEL_FILE"
  fi

  cp "$NEXT_LEVEL_FILE" "$CURRENT_LEVEL_FILE"
  current_depth=$((current_depth + 1))
done

# --- Output ---

unique_tags=$(sort -u "$TAGS_FILE" 2>/dev/null | grep -v '^$' || true)
unique_titles=$(sort -u "$GRAPH_FILE.titles" 2>/dev/null | grep -v '^$' || true)
unique_source_beads=$(sort -u "$SOURCE_BEADS_FILE" 2>/dev/null | grep -v '^$' || true)
graph_beads=$(cat "$GRAPH_FILE" 2>/dev/null | grep -v '^$' || true)

case "$FORMAT" in
  tags)
    echo "$unique_tags"
    ;;

  json)
    python3 -c "
import json, sys

tags = [t for t in '''${unique_tags}'''.split('\n') if t.strip()]
titles = [t for t in '''${unique_titles}'''.split('\n') if t.strip()]
source_beads = [s for s in '''${unique_source_beads}'''.split('\n') if s.strip()]

graph_beads = []
for line in '''${graph_beads}'''.split('\n'):
    if not line.strip():
        continue
    parts = line.split('|', 2)
    if len(parts) == 3:
        graph_beads.append({
            'id': parts[0],
            'distance': int(parts[1]),
            'title': parts[2]
        })

result = {
    'root_bead': '$BEAD_ID',
    'depth': $DEPTH,
    'beads_visited': len(graph_beads),
    'graph_beads': graph_beads,
    'tags': tags,
    'titles': titles,
    'source_beads': source_beads
}

print(json.dumps(result, indent=2))
"
    ;;

  *)
    log_error "Unknown format: $FORMAT"
    exit 1
    ;;
esac
