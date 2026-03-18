#!/bin/bash
# Knowledge Nominate Check — Auto-nomination heuristic for bead close
#
# Scores a bead on signals that indicate reusable knowledge, and either
# prompts the user (interactive) or creates a nomination bead (non-interactive).
#
# Usage:
#   knowledge-nominate-check.sh <bead-id>
#   knowledge-nominate-check.sh <bead-id> --non-interactive
#   knowledge-nominate-check.sh <bead-id> --threshold 5
#   knowledge-nominate-check.sh <bead-id> --dry-run
#
# Heuristic scoring:
#   reopened(+3), comments>2(+2), bug/incident(+2),
#   children(+1), blocked others(+1), gotcha/workaround label(+3)
#
# Hook registration:
#   Use as a post-close hook in Gas Town or beads formula.

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

# --- Defaults ---
BEAD_ID=""
NON_INTERACTIVE=false
DRY_RUN=false
THRESHOLD=""
PROFILE_THRESHOLD=""

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --non-interactive) NON_INTERACTIVE=true; shift;;
    --dry-run)         DRY_RUN=true; shift;;
    --threshold)       THRESHOLD="${2:-3}"; shift 2;;
    --help|-h)
      echo "Knowledge Nominate Check — Auto-nomination heuristic for bead close"
      echo ""
      echo "Usage: knowledge-nominate-check.sh <bead-id> [options]"
      echo ""
      echo "Options:"
      echo "  --non-interactive  Create nomination bead instead of prompting"
      echo "  --dry-run          Score and report without prompting or creating beads"
      echo "  --threshold <n>    Override nomination threshold (default: from profile or 3)"
      echo ""
      echo "Scoring:"
      echo "  reopened             +3"
      echo "  comments > 2         +2"
      echo "  type = bug/incident  +2"
      echo "  has children         +1"
      echo "  blocked other work   +1"
      echo "  gotcha/workaround    +3"
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
  echo "Usage: knowledge-nominate-check.sh <bead-id> [--non-interactive] [--dry-run]"
  exit 1
fi

# --- Load threshold from tavern-profile.yaml if not overridden ---
if [[ -z "$THRESHOLD" ]]; then
  # Search for tavern-profile.yaml in common locations
  for candidate in \
    "$TAVERN_ROOT/tavern-profile.yaml" \
    "$TAVERN_ROOT/templates/tavern-profile.yaml"; do
    if [[ -f "$candidate" ]]; then
      PROFILE_THRESHOLD=$(grep -E '^\s*auto_nominate_threshold:' "$candidate" 2>/dev/null \
        | head -1 | sed 's/.*: *//' | sed 's/ *#.*//' | tr -d ' ' || true)
      if [[ -n "$PROFILE_THRESHOLD" ]]; then
        THRESHOLD="$PROFILE_THRESHOLD"
        break
      fi
    fi
  done
  THRESHOLD="${THRESHOLD:-3}"
fi

# --- Fetch bead data ---
BEAD_JSON=$(bd show "$BEAD_ID" --json 2>/dev/null) || {
  log_error "Failed to fetch bead: $BEAD_ID"
  exit 1
}

# bd show --json returns an array; extract first element
BEAD=$(echo "$BEAD_JSON" | jq '.[0]' 2>/dev/null) || {
  log_error "Failed to parse bead JSON for: $BEAD_ID"
  exit 1
}

if [[ "$BEAD" == "null" ]] || [[ -z "$BEAD" ]]; then
  log_error "Bead not found: $BEAD_ID"
  exit 1
fi

BEAD_TITLE=$(echo "$BEAD" | jq -r '.title // ""')
BEAD_TYPE=$(echo "$BEAD" | jq -r '.issue_type // ""')
BEAD_LABELS=$(echo "$BEAD" | jq -r '.labels // [] | .[]' 2>/dev/null || true)

# --- Scoring ---
SCORE=0
SIGNALS=""

# Signal 1: Bead was reopened (+3)
# Check history for closed → non-closed transition
REOPENED=false
if command -v bd &>/dev/null; then
  HISTORY_STATUSES=$(bd history "$BEAD_ID" --json 2>/dev/null \
    | jq -r '.[].Issue.status // empty' 2>/dev/null || true)
  if [[ -n "$HISTORY_STATUSES" ]]; then
    PREV_STATUS=""
    while IFS= read -r status; do
      if [[ "$PREV_STATUS" == "closed" ]] && [[ "$status" != "closed" ]]; then
        REOPENED=true
        break
      fi
      PREV_STATUS="$status"
    done <<< "$HISTORY_STATUSES"
  fi
fi
if [[ "$REOPENED" == "true" ]]; then
  SCORE=$((SCORE + 3))
  SIGNALS="${SIGNALS}  reopened (+3)\n"
fi

# Signal 2: Bead has >2 comments (+2)
COMMENT_COUNT=0
if command -v bd &>/dev/null; then
  COMMENT_COUNT=$(bd comments "$BEAD_ID" --json 2>/dev/null \
    | jq 'length' 2>/dev/null || echo "0")
fi
if [[ "$COMMENT_COUNT" -gt 2 ]] 2>/dev/null; then
  SCORE=$((SCORE + 2))
  SIGNALS="${SIGNALS}  comments=${COMMENT_COUNT} (+2)\n"
fi

# Signal 3: Bead type is bug or incident (+2)
if [[ "$BEAD_TYPE" == "bug" ]] || [[ "$BEAD_TYPE" == "incident" ]]; then
  SCORE=$((SCORE + 2))
  SIGNALS="${SIGNALS}  type=${BEAD_TYPE} (+2)\n"
fi

# Signal 4: Bead has children (+1)
CHILD_COUNT=0
if command -v bd &>/dev/null; then
  CHILD_COUNT=$(bd children "$BEAD_ID" --json 2>/dev/null \
    | jq 'length' 2>/dev/null || echo "0")
fi
if [[ "$CHILD_COUNT" -gt 0 ]] 2>/dev/null; then
  SCORE=$((SCORE + 1))
  SIGNALS="${SIGNALS}  children=${CHILD_COUNT} (+1)\n"
fi

# Signal 5: Bead blocked other work (+1)
# Check if any dependency has type "blocked_by" (meaning this bead blocked something)
BLOCKED_OTHERS=false
if command -v bd &>/dev/null; then
  BLOCKED_COUNT=$(echo "$BEAD" | jq '[.dependencies // [] | .[] | select(.dependency_type == "blocked_by")] | length' 2>/dev/null || echo "0")
  if [[ "$BLOCKED_COUNT" -gt 0 ]] 2>/dev/null; then
    BLOCKED_OTHERS=true
  fi
  # Also check reverse: query for beads that depend on this one
  if [[ "$BLOCKED_OTHERS" == "false" ]]; then
    REVERSE_BLOCKED=$(bd query "description:$BEAD_ID" --json 2>/dev/null \
      | jq "[.[] | select(.dependencies[]?.id == \"$BEAD_ID\" and .dependencies[]?.dependency_type == \"blocks\")] | length" 2>/dev/null || echo "0")
    if [[ "$REVERSE_BLOCKED" -gt 0 ]] 2>/dev/null; then
      BLOCKED_OTHERS=true
    fi
  fi
fi
if [[ "$BLOCKED_OTHERS" == "true" ]]; then
  SCORE=$((SCORE + 1))
  SIGNALS="${SIGNALS}  blocked-others (+1)\n"
fi

# Signal 6: Labels include gotcha or workaround (+3)
GOTCHA_MATCH=false
if [[ -n "$BEAD_LABELS" ]]; then
  while IFS= read -r label; do
    case "$label" in
      *gotcha*|*workaround*|*footgun*)
        GOTCHA_MATCH=true
        break
        ;;
    esac
  done <<< "$BEAD_LABELS"
fi
if [[ "$GOTCHA_MATCH" == "true" ]]; then
  SCORE=$((SCORE + 3))
  SIGNALS="${SIGNALS}  gotcha/workaround label (+3)\n"
fi

# --- Report ---
if [[ -n "$SIGNALS" ]]; then
  log_info "Nomination score for $BEAD_ID: ${SCORE}/${THRESHOLD}"
  echo -e "$SIGNALS"
else
  log_info "Nomination score for $BEAD_ID: 0/${THRESHOLD} (no signals)"
fi

# --- Decision ---
if [[ "$SCORE" -lt "$THRESHOLD" ]]; then
  log_info "Score below threshold — no nomination suggested"
  exit 0
fi

# Score meets threshold
if [[ "$DRY_RUN" == "true" ]]; then
  log_success "Score meets threshold — would nominate (dry-run)"
  exit 0
fi

if [[ "$NON_INTERACTIVE" == "true" ]]; then
  # Non-interactive: create a nomination bead
  log_info "Creating nomination bead for $BEAD_ID..."

  NOMINATION_ID=$(bd q -t task \
    "Knowledge candidate: ${BEAD_TITLE}" \
    -l "auto-nominated" 2>/dev/null) || {
    log_error "Failed to create nomination bead"
    exit 1
  }

  # Add relates_to link back to the source bead
  bd update "$NOMINATION_ID" \
    --notes "Auto-nominated from $BEAD_ID (score: $SCORE/$THRESHOLD).
Signals:
$(echo -e "$SIGNALS")
Review this bead for knowledge worth capturing." 2>/dev/null || true

  log_success "Created nomination bead: $NOMINATION_ID (relates to $BEAD_ID)"
  echo "$NOMINATION_ID"
else
  # Interactive: prompt the user
  echo ""
  log_success "This bead looks like it contains reusable knowledge (score: ${SCORE}/${THRESHOLD})"
  echo ""
  echo "  Bead:  $BEAD_ID — $BEAD_TITLE"
  echo -e "$SIGNALS"
  echo "Consider nominating with:"
  echo "  gt rally nominate --issue $BEAD_ID --title \"$BEAD_TITLE\""
  echo ""

  # If stdin is a terminal, prompt
  if [[ -t 0 ]]; then
    read -r -p "Nominate now? [Y/n] " REPLY
    REPLY="${REPLY:-Y}"
    case "$REPLY" in
      [Yy]*)
        log_info "Opening nomination..."
        gt rally nominate --issue "$BEAD_ID" --title "$BEAD_TITLE" 2>/dev/null || {
          log_warn "gt rally nominate failed — you can nominate manually later"
        }
        ;;
      *)
        log_info "Skipped nomination"
        ;;
    esac
  fi
fi
