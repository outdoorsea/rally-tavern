#!/bin/bash
# Knowledge Auto-Inject — Graduated knowledge injection for gt prime
#
# Scans the knowledge index and outputs entries eligible for auto-injection
# based on graduation status:
#   - Verified (<60d since last_verified): auto-inject (trusted)
#   - New (<7d since created_at): auto-inject with [NEW] tag
#   - Unverified/stale: pull-only (not injected; use `gt rally lookup`)
#
# Entries are filtered against a tavern-profile.yaml (if present) for relevance.
#
# Usage:
#   knowledge-auto-inject.sh                          # Use profile from cwd
#   knowledge-auto-inject.sh --profile /path/to/dir   # Specify profile location
#   knowledge-auto-inject.sh --tags "go,security"     # Override profile with tags
#   knowledge-auto-inject.sh --max 3                  # Limit injected entries
#
# Output: Markdown block suitable for gt prime injection. Empty if no matches.

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

PROFILE_DIR="${PWD}"
TAGS=""
CODEBASE_TYPE=""
MAX_RESULTS=5
KNOWLEDGE_DIR="$TAVERN_ROOT/knowledge"

# Graduation thresholds (in seconds)
NEW_THRESHOLD=$((7 * 86400))         # 7 days
VERIFIED_THRESHOLD=$((60 * 86400))   # 60 days

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)    PROFILE_DIR="${2:-.}"; shift 2;;
    --tags)       TAGS="${2:-}"; shift 2;;
    --codebase)   CODEBASE_TYPE="${2:-}"; shift 2;;
    --max)        MAX_RESULTS="${2:-5}"; shift 2;;
    --help|-h)
      echo "Knowledge Auto-Inject — Graduated knowledge injection for gt prime"
      echo ""
      echo "Usage: knowledge-auto-inject.sh [options]"
      echo ""
      echo "Options:"
      echo "  --profile <dir>   Directory containing tavern-profile.yaml (default: cwd)"
      echo "  --tags <t1,t2>    Override profile tags (comma-separated)"
      echo "  --codebase <type> Override profile codebase_type"
      echo "  --max <n>         Maximum entries to inject (default: 5)"
      echo ""
      echo "Graduation levels:"
      echo "  Verified (<60d):  Auto-injected as trusted knowledge"
      echo "  New (<7d):        Auto-injected with [NEW] tag"
      echo "  Unverified/stale: Not injected (use 'gt rally lookup')"
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1" >&2
      exit 1
      ;;
    *)  shift;;
  esac
done

if [[ ! -d "$KNOWLEDGE_DIR" ]]; then
  exit 0  # Silent exit — rally_tavern knowledge not available
fi

# --- Build search terms from profile or flags ---

tag_list=""
if [[ -n "$TAGS" ]]; then
  tag_list=$(echo "$TAGS" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')
elif [[ -f "$PROFILE_DIR/tavern-profile.yaml" ]]; then
  # Extract tags from profile
  profile="$PROFILE_DIR/tavern-profile.yaml"
  profile_tags=$(yaml_get "$profile" "tags" 2>/dev/null || true)
  # Strip brackets and split
  profile_tags=$(echo "$profile_tags" | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')

  # Also extract languages and frameworks as tags
  languages=$(sed -n '/^  languages:/,/^  [a-z]/p' "$profile" 2>/dev/null | grep "^    -" | sed 's/^    - //' | tr -d '[:space:]' || true)
  frameworks=$(sed -n '/^  frameworks:/,/^  [a-z]/p' "$profile" 2>/dev/null | grep "^    -" | sed 's/^    - //' | tr -d '[:space:]' || true)

  tag_list=$(printf '%s\n%s\n%s\n' "$profile_tags" "$languages" "$frameworks" | grep -v '^$' | sort -u)

  if [[ -z "$CODEBASE_TYPE" ]]; then
    # Derive codebase_type from first language + first framework
    first_lang=$(echo "$languages" | head -1)
    first_fw=$(echo "$frameworks" | head -1)
    if [[ -n "$first_lang" ]] && [[ -n "$first_fw" ]]; then
      CODEBASE_TYPE="${first_lang}-${first_fw}"
    elif [[ -n "$first_lang" ]]; then
      CODEBASE_TYPE="$first_lang"
    fi
  fi
fi

# If no tags or codebase type to filter on, skip injection
if [[ -z "$tag_list" ]] && [[ -z "$CODEBASE_TYPE" ]]; then
  exit 0
fi

# --- Classify and score each knowledge entry ---

NOW_EPOCH=$(date "+%s")
SCORE_FILE=$(mktemp)
trap "rm -f '$SCORE_FILE'" EXIT

while IFS= read -r kfile; do
  [[ -z "$kfile" ]] && continue

  content=$(cat "$kfile" 2>/dev/null) || continue
  echo "$content" | grep -q "^title:" || continue

  # Skip deprecated entries
  deprecated=$(echo "$content" | grep "^deprecated:" | head -1 | cut -d: -f2- | xargs 2>/dev/null || true)
  if [[ "$deprecated" == "true" ]]; then
    continue
  fi

  # --- Determine graduation level ---
  grad_level="pull-only"
  grad_tag=""

  # Check verified status
  verified_by=$(echo "$content" | grep "^verified_by:" | head -1 | cut -d: -f2- | xargs 2>/dev/null || true)
  last_verified=$(echo "$content" | grep "^last_verified:" | head -1 | cut -d: -f2- | xargs 2>/dev/null || true)
  created_at=$(echo "$content" | grep "^created_at:" | head -1 | cut -d: -f2- | xargs 2>/dev/null || true)

  if [[ -n "$verified_by" ]] && [[ "$verified_by" != "[]" ]]; then
    # Has verifiers — check staleness
    verify_date=""
    if [[ -n "$last_verified" ]]; then
      verify_date="${last_verified%%T*}"
    elif [[ -n "$created_at" ]]; then
      # Fallback: use created_at as verification date
      verify_date="${created_at%%T*}"
    fi

    if [[ -n "$verify_date" ]]; then
      if verify_epoch=$(date -j -f "%Y-%m-%d" "$verify_date" "+%s" 2>/dev/null); then
        age_secs=$((NOW_EPOCH - verify_epoch))
        if [[ $age_secs -le $VERIFIED_THRESHOLD ]]; then
          grad_level="verified"
        fi
      fi
    fi
  fi

  # Check new status (only if not already verified)
  if [[ "$grad_level" == "pull-only" ]] && [[ -n "$created_at" ]]; then
    created_date="${created_at%%T*}"
    if created_epoch=$(date -j -f "%Y-%m-%d" "$created_date" "+%s" 2>/dev/null); then
      age_secs=$((NOW_EPOCH - created_epoch))
      if [[ $age_secs -le $NEW_THRESHOLD ]]; then
        grad_level="new"
        grad_tag=" [NEW]"
      fi
    fi
  fi

  # Skip pull-only entries
  if [[ "$grad_level" == "pull-only" ]]; then
    continue
  fi

  # --- Score relevance ---
  score=0

  # Tag matches
  if [[ -n "$tag_list" ]]; then
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      if echo "$content" | grep -qi "tags:.*${tag}"; then
        score=$((score + 3))
      fi
      if echo "$content" | grep -qi "codebase_type:.*${tag}"; then
        score=$((score + 2))
      fi
    done <<< "$tag_list"
  fi

  # Codebase type match
  if [[ -n "$CODEBASE_TYPE" ]]; then
    if echo "$content" | grep -qi "codebase_type:.*${CODEBASE_TYPE}"; then
      score=$((score + 2))
    fi
  fi

  if [[ $score -le 0 ]]; then
    continue
  fi

  entry_title=$(echo "$content" | grep "^title:" | head -1 | cut -d: -f2- | xargs)
  entry_kind=$(basename "$(dirname "$kfile")")
  # Singularize: practices->practice, solutions->solution, learned->learned
  entry_kind="${entry_kind%s}"
  [[ "$entry_kind" == "learned" ]] || true

  # Format: score|file|grad_level|grad_tag|kind|title
  echo "${score}|${kfile}|${grad_level}|${grad_tag}|${entry_kind}|${entry_title}" >> "$SCORE_FILE"

done < <(find "$KNOWLEDGE_DIR" -name "*.yaml" -type f 2>/dev/null)

# --- Rank, limit, and output ---

if [[ ! -s "$SCORE_FILE" ]]; then
  exit 0
fi

ranked=$(sort -t'|' -k1 -nr "$SCORE_FILE" | head -n "$MAX_RESULTS")

# Count results
result_count=$(echo "$ranked" | wc -l | xargs)
if [[ "$result_count" -eq 0 ]]; then
  exit 0
fi

echo "# Rally Tavern Knowledge (auto-injected)"
echo ""
echo "The following verified knowledge was matched for this repo's profile."
echo "Unverified entries require explicit \`gt rally lookup <tag>\`."
echo ""

echo "$ranked" | while IFS='|' read -r score file grad_level grad_tag kind title; do
  echo "### ${title} (${kind})${grad_tag}"
  echo ""

  # Extract summary or lesson
  summary=$(yaml_get "$file" "summary" 2>/dev/null || true)
  lesson=$(yaml_get "$file" "lesson" 2>/dev/null || true)

  # Handle multiline YAML values (| indicator)
  if [[ "$summary" == "|" ]]; then
    summary=$(sed -n '/^summary:/,/^[a-z]/p' "$file" 2>/dev/null | grep "^  " | sed 's/^  //' | head -5 || true)
  fi
  if [[ "$lesson" == "|" ]]; then
    lesson=$(sed -n '/^lesson:/,/^[a-z]/p' "$file" 2>/dev/null | grep "^  " | sed 's/^  //' | head -5 || true)
  fi

  if [[ -n "$summary" ]] && [[ "$summary" != "|" ]]; then
    echo "$summary"
    echo ""
  fi
  if [[ -n "$lesson" ]] && [[ "$lesson" != "|" ]]; then
    echo "**Lesson:** $lesson"
    echo ""
  fi

  # Extract gotchas if present
  gotchas=$(sed -n '/^gotchas:/,/^[a-z]/p' "$file" 2>/dev/null | grep "^  -" | head -5 || true)
  if [[ -n "$gotchas" ]]; then
    echo "**Gotchas:**"
    echo "$gotchas"
    echo ""
  fi

  echo "---"
  echo ""
done
