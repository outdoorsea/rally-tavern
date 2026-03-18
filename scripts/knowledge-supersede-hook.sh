#!/bin/bash
# Knowledge Supersede Hook — Post-close hook for bead supersedes links
#
# When a bead is closed with a `supersedes` link, this hook checks if the
# superseded bead has linked knowledge entries (via knowledge:* labels) and
# flags those entries for review.
#
# Usage (called by bd close post-hook or manually):
#   knowledge-supersede-hook.sh <closed-bead-id>
#   knowledge-supersede-hook.sh <closed-bead-id> --auto-flag
#   knowledge-supersede-hook.sh <closed-bead-id> --create-task
#
# This implements §3.4 of the Beads-Knowledge Integration design spec.

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

AUTO_FLAG=false
CREATE_TASK=false
KNOWLEDGE_DIR="$TAVERN_ROOT/knowledge"

show_help() {
  echo "Knowledge Supersede Hook — Flag knowledge when source beads are superseded"
  echo ""
  echo "Usage: knowledge-supersede-hook.sh <bead-id> [options]"
  echo ""
  echo "Options:"
  echo "  --auto-flag     Automatically add needs_review to flagged entries"
  echo "  --create-task   Create a review task bead for each flagged entry"
  echo ""
  echo "This hook should be called after bd close when the closed bead"
  echo "has supersedes links. It checks if the superseded beads have"
  echo "linked knowledge entries and flags them for review."
  exit 0
}

# Parse args
BEAD_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-flag)    AUTO_FLAG=true; shift;;
    --create-task)  CREATE_TASK=true; shift;;
    --help|-h)      show_help;;
    *)
      if [[ -z "$BEAD_ID" ]]; then
        BEAD_ID="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$BEAD_ID" ]]; then
  log_error "Usage: knowledge-supersede-hook.sh <bead-id>"
  exit 1
fi

# Verify bd is available
if ! command -v bd &>/dev/null; then
  log_error "bd command not found — cannot check bead links"
  exit 1
fi

# Get the bead's JSON data
BEAD_JSON=$(bd show "$BEAD_ID" --json 2>/dev/null || echo "[]")

if [[ "$BEAD_JSON" == "[]" ]]; then
  log_error "Bead not found: $BEAD_ID"
  exit 1
fi

# Find superseded beads (beads that this bead supersedes)
SUPERSEDED_BEADS=$(echo "$BEAD_JSON" | jq -r '
  .[0].dependencies[]? |
  select(.dependency_type == "supersedes") |
  .id // empty
' 2>/dev/null || echo "")

if [[ -z "$SUPERSEDED_BEADS" ]]; then
  # No supersedes links — nothing to do
  exit 0
fi

FLAGGED_COUNT=0

for superseded_id in $SUPERSEDED_BEADS; do
  # Check if the superseded bead has knowledge:* labels
  KNOWLEDGE_LABELS=$(bd label list "$superseded_id" 2>/dev/null | grep "^knowledge:" || echo "")

  if [[ -z "$KNOWLEDGE_LABELS" ]]; then
    # No knowledge backlinks on this bead — check if any knowledge entry
    # has this bead in its source_beads field (forward search)
    while IFS= read -r -d '' file; do
      if grep -q "source_beads:.*$superseded_id" "$file" 2>/dev/null; then
        entry_id=$(yaml_get "$file" "id")
        [[ -z "$entry_id" ]] && continue

        log_warn "Knowledge entry '$entry_id' references superseded bead $superseded_id"
        FLAGGED_COUNT=$((FLAGGED_COUNT + 1))

        if [[ "$AUTO_FLAG" == "true" ]]; then
          local_reason="superseded by $BEAD_ID (source bead $superseded_id)"

          if ! grep -q "^needs_review:" "$file" 2>/dev/null; then
            echo "needs_review: true" >> "$file"
          else
            sed -i '' 's/^needs_review:.*/needs_review: true/' "$file"
          fi

          if ! grep -q "^staleness_reason:" "$file" 2>/dev/null; then
            echo "staleness_reason: \"$local_reason\"" >> "$file"
          else
            sed -i '' "s/^staleness_reason:.*/staleness_reason: \"$local_reason\"/" "$file"
          fi

          log_success "Flagged: $entry_id — $local_reason"
        fi

        if [[ "$CREATE_TASK" == "true" ]]; then
          bd create --title "Review knowledge: $entry_id (superseded source)" \
            --type task \
            --label "knowledge-review" \
            --label "auto-generated" 2>/dev/null || true
          log_info "Created review task for $entry_id"
        fi
      fi
    done < <(find "$KNOWLEDGE_DIR" -name "*.yaml" -print0 2>/dev/null)
    continue
  fi

  # Process knowledge:* labels on the superseded bead
  while IFS= read -r label; do
    # Extract entry ID from label (knowledge:entry-id → entry-id)
    entry_id="${label#knowledge:}"
    [[ -z "$entry_id" ]] && continue

    # Find the knowledge file
    entry_file=$(find "$KNOWLEDGE_DIR" -name "*.yaml" -exec grep -l "^id: $entry_id$" {} \; 2>/dev/null | head -1)

    if [[ -z "$entry_file" ]]; then
      log_warn "Knowledge entry '$entry_id' referenced by label on $superseded_id but file not found"
      continue
    fi

    log_warn "Knowledge entry '$entry_id' linked to superseded bead $superseded_id"
    FLAGGED_COUNT=$((FLAGGED_COUNT + 1))

    if [[ "$AUTO_FLAG" == "true" ]]; then
      local_reason="superseded by $BEAD_ID (source bead $superseded_id)"

      if ! grep -q "^needs_review:" "$entry_file" 2>/dev/null; then
        echo "needs_review: true" >> "$entry_file"
      else
        sed -i '' 's/^needs_review:.*/needs_review: true/' "$entry_file"
      fi

      if ! grep -q "^staleness_reason:" "$entry_file" 2>/dev/null; then
        echo "staleness_reason: \"$local_reason\"" >> "$entry_file"
      else
        sed -i '' "s/^staleness_reason:.*/staleness_reason: \"$local_reason\"/" "$entry_file"
      fi

      log_success "Flagged: $entry_id — $local_reason"
    fi

    if [[ "$CREATE_TASK" == "true" ]]; then
      bd create --title "Review knowledge: $entry_id (superseded source)" \
        --type task \
        --label "knowledge-review" \
        --label "auto-generated" 2>/dev/null || true
      log_info "Created review task for $entry_id"
    fi
  done <<< "$KNOWLEDGE_LABELS"
done

# Summary
if [[ $FLAGGED_COUNT -gt 0 ]]; then
  log_warn "$FLAGGED_COUNT knowledge entries linked to superseded beads"
  if [[ "$AUTO_FLAG" != "true" ]]; then
    echo "  Run with --auto-flag to add needs_review markers"
  fi
else
  log_success "No knowledge entries affected by supersedes links"
fi

exit 0
