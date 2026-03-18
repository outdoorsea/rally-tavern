#!/bin/bash
# Knowledge Staleness Detection — Graph-aware staleness signals
#
# Scans knowledge entries for staleness using two mechanisms:
#   1. Graph-based: checks if source_beads have been superseded
#   2. Flag-based: reports entries already flagged with needs_review
#
# Usage:
#   knowledge-stale.sh                    # Report all stale/flagged entries
#   knowledge-stale.sh --check            # Exit 1 if any stale entries found
#   knowledge-stale.sh --flag             # Auto-flag entries with superseded sources
#   knowledge-stale.sh --format json      # JSON output for MCP consumption
#   knowledge-stale.sh --category practices  # Only check practices/
#
# Output:
#   Lists knowledge entries that are stale or need review, with reasons.

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

MODE="report"       # report | check | flag
FORMAT="text"        # text | json
CATEGORY=""          # empty = all categories
KNOWLEDGE_DIR="$TAVERN_ROOT/knowledge"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)    MODE="check"; shift;;
    --flag)     MODE="flag"; shift;;
    --format)   FORMAT="${2:-text}"; shift 2;;
    --category) CATEGORY="${2:-}"; shift 2;;
    --help|-h)
      echo "Knowledge Staleness Detection — Graph-aware signals"
      echo ""
      echo "Usage: knowledge-stale.sh [options]"
      echo ""
      echo "Options:"
      echo "  --check              Exit 1 if any stale entries found (for CI)"
      echo "  --flag               Auto-flag entries with superseded sources"
      echo "  --format <fmt>       Output format: text (default), json"
      echo "  --category <cat>     Only check category (practices, solutions, learned, postmortems)"
      echo ""
      echo "Staleness signals:"
      echo "  1. source_beads superseded — a source bead was superseded by newer work"
      echo "  2. needs_review flag — entry already flagged for review"
      echo "  3. canary marker — entry contains canary/test markers"
      exit 0
      ;;
    *) shift;;
  esac
done

# Collect categories to scan
CATEGORIES=()
if [[ -n "$CATEGORY" ]]; then
  CATEGORIES=("$CATEGORY")
else
  for dir in "$KNOWLEDGE_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    dirname=$(basename "$dir")
    # Skip non-knowledge directories
    [[ "$dirname" == "repos" || "$dirname" == "starters" ]] && continue
    CATEGORIES+=("$dirname")
  done
fi

# Results accumulator
declare -a STALE_ENTRIES=()
STALE_COUNT=0
JSON_RESULTS="[]"

# Check if bd is available for graph queries
BD_AVAILABLE=false
if command -v bd &>/dev/null; then
  BD_AVAILABLE=true
fi

# --- Scanning functions ---

# Extract source_beads from a YAML file (simple grep-based parser)
get_source_beads() {
  local file="$1"
  local line
  line=$(grep "^source_beads:" "$file" 2>/dev/null || echo "")
  if [[ -z "$line" ]]; then
    echo ""
    return
  fi
  # Parse [id1, id2] format
  echo "$line" | sed 's/^source_beads:\s*//' | tr -d '[]' | tr ',' '\n' | xargs
}

# Check if an entry has needs_review flag
has_needs_review() {
  local file="$1"
  grep -q "^needs_review:\s*true" "$file" 2>/dev/null
}

# Get the staleness_reason if present
get_staleness_reason() {
  local file="$1"
  grep "^staleness_reason:" "$file" 2>/dev/null | sed 's/^staleness_reason:\s*//' | tr -d '"' || echo ""
}

# Check if a bead has been superseded (via bd show --json)
check_bead_superseded() {
  local bead_id="$1"
  if [[ "$BD_AVAILABLE" != "true" ]]; then
    echo ""
    return
  fi

  local json
  json=$(bd show "$bead_id" --json 2>/dev/null || echo "[]")

  # Check for superseded_by links in the JSON output
  local superseder
  superseder=$(echo "$json" | jq -r '
    .[0].dependencies[]? |
    select(.dependency_type == "superseded_by" or .dependency_type == "supersedes") |
    .id // empty
  ' 2>/dev/null || echo "")

  # Also check labels for superseded markers
  if [[ -z "$superseder" ]]; then
    superseder=$(echo "$json" | jq -r '
      .[0].labels[]? |
      select(startswith("superseded-by:")) |
      sub("^superseded-by:"; "")
    ' 2>/dev/null || echo "")
  fi

  echo "$superseder"
}

# Check if a bead is closed
check_bead_closed() {
  local bead_id="$1"
  if [[ "$BD_AVAILABLE" != "true" ]]; then
    echo ""
    return
  fi

  local status
  status=$(bd show "$bead_id" --json 2>/dev/null | jq -r '.[0].status // ""' 2>/dev/null || echo "")
  echo "$status"
}

# Flag a knowledge entry as needing review
flag_entry() {
  local file="$1"
  local reason="$2"

  # Add needs_review and staleness_reason if not already present
  if ! grep -q "^needs_review:" "$file" 2>/dev/null; then
    echo "needs_review: true" >> "$file"
  else
    sed -i '' 's/^needs_review:.*/needs_review: true/' "$file"
  fi

  if ! grep -q "^staleness_reason:" "$file" 2>/dev/null; then
    echo "staleness_reason: \"$reason\"" >> "$file"
  else
    sed -i '' "s/^staleness_reason:.*/staleness_reason: \"$reason\"/" "$file"
  fi
}

# Add a result to the accumulator
add_result() {
  local file="$1"
  local entry_id="$2"
  local reason="$3"
  local signal_type="$4"

  STALE_COUNT=$((STALE_COUNT + 1))

  if [[ "$FORMAT" == "json" ]]; then
    local rel_path="${file#"$KNOWLEDGE_DIR/"}"
    JSON_RESULTS=$(echo "$JSON_RESULTS" | jq \
      --arg file "$rel_path" \
      --arg id "$entry_id" \
      --arg reason "$reason" \
      --arg signal "$signal_type" \
      '. + [{"file": $file, "id": $id, "reason": $reason, "signal_type": $signal}]')
  else
    STALE_ENTRIES+=("$entry_id|$reason|$signal_type|$file")
  fi
}

# --- Main scan ---

for category in "${CATEGORIES[@]}"; do
  category_dir="$KNOWLEDGE_DIR/$category"
  [[ -d "$category_dir" ]] || continue

  for file in "$category_dir"/*.yaml; do
    [[ -f "$file" ]] || continue

    entry_id=$(yaml_get "$file" "id")
    [[ -z "$entry_id" ]] && continue

    # Signal 1: Already flagged with needs_review
    if has_needs_review "$file"; then
      reason=$(get_staleness_reason "$file")
      [[ -z "$reason" ]] && reason="manually flagged"
      add_result "$file" "$entry_id" "$reason" "flagged"
      continue  # Already flagged, skip other checks
    fi

    # Signal 2: Canary/test markers
    if grep -q "canary" "$file" 2>/dev/null && grep -q "DELIBERATELY WRONG\|staleness-test\|canary.*test" "$file" 2>/dev/null; then
      add_result "$file" "$entry_id" "canary test entry — should be flagged or removed" "canary"
      if [[ "$MODE" == "flag" ]]; then
        flag_entry "$file" "canary test entry detected by automated scan"
        log_warn "Flagged canary entry: $entry_id"
      fi
      continue
    fi

    # Signal 3: source_beads superseded (graph-based)
    source_beads=$(get_source_beads "$file")
    if [[ -n "$source_beads" ]]; then
      for bead_id in $source_beads; do
        superseder=$(check_bead_superseded "$bead_id")
        if [[ -n "$superseder" ]]; then
          reason="source bead $bead_id superseded by $superseder"
          add_result "$file" "$entry_id" "$reason" "superseded"
          if [[ "$MODE" == "flag" ]]; then
            flag_entry "$file" "$reason"
            log_warn "Flagged: $entry_id — $reason"
          fi
          break  # One superseded source is enough to flag
        fi
      done
    fi
  done
done

# --- Output ---

if [[ "$FORMAT" == "json" ]]; then
  echo "$JSON_RESULTS" | jq '{
    stale_count: (. | length),
    timestamp: (now | todate),
    entries: .
  }'
else
  if [[ $STALE_COUNT -eq 0 ]]; then
    log_success "No stale knowledge entries found."
  else
    echo ""
    log_warn "Found $STALE_COUNT stale/flagged knowledge entries:"
    echo ""
    for entry in "${STALE_ENTRIES[@]}"; do
      IFS='|' read -r id reason signal file <<< "$entry"
      case "$signal" in
        flagged)    icon="🚩";;
        canary)     icon="🐤";;
        superseded) icon="♻️";;
        *)          icon="❓";;
      esac
      echo "  $icon $id"
      echo "    Reason: $reason"
      echo "    Signal: $signal"
      echo "    File:   ${file#"$KNOWLEDGE_DIR/"}"
      echo ""
    done
  fi
fi

# --- Exit code ---

if [[ "$MODE" == "check" && $STALE_COUNT -gt 0 ]]; then
  exit 1
fi

exit 0
