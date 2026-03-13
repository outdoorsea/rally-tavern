#!/bin/bash
# Knowledge Push — Proactive knowledge injection for polecat dispatch
#
# Given a bead's tags and/or title, finds relevant knowledge entries from the
# Rally Tavern knowledge index and outputs them in a format suitable for
# injection into polecat hook context.
#
# Usage:
#   knowledge-push.sh --tags "gas-town,beads,workflow"
#   knowledge-push.sh --title "Fix polecat crash loop in hooks"
#   knowledge-push.sh --tags "gas-town" --title "hooks cleanup"
#   knowledge-push.sh --tags "gas-town" --format yaml
#   knowledge-push.sh --tags "gas-town" --max 3
#
# Output formats:
#   markdown (default) — Human-readable context block for CLAUDE.md injection
#   yaml               — Machine-readable list of matched entries
#   paths              — Just file paths of matched entries

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

TAGS=""
TITLE=""
FORMAT="markdown"
MAX_RESULTS=5
KNOWLEDGE_DIR="$TAVERN_ROOT/knowledge"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tags)     TAGS="${2:-}"; shift 2;;
    --title)    TITLE="${2:-}"; shift 2;;
    --format)   FORMAT="${2:-markdown}"; shift 2;;
    --max)      MAX_RESULTS="${2:-5}"; shift 2;;
    --help|-h)
      echo "Knowledge Push — Proactive knowledge injection"
      echo ""
      echo "Usage: knowledge-push.sh [options]"
      echo ""
      echo "Options:"
      echo "  --tags <t1,t2,...>  Comma-separated tags to match against knowledge entries"
      echo "  --title <text>     Bead title — extracted keywords match against knowledge"
      echo "  --format <fmt>     Output format: markdown (default), yaml, paths"
      echo "  --max <n>          Maximum entries to return (default: 5)"
      echo ""
      echo "Searches knowledge/ for entries whose tags overlap with the given tags"
      echo "or whose content matches keywords from the title. Results are ranked"
      echo "by tag overlap count."
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      exit 1
      ;;
    *)
      if [[ -z "$TITLE" ]]; then
        TITLE="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$TAGS" ]] && [[ -z "$TITLE" ]]; then
  log_error "At least one of --tags or --title is required"
  exit 1
fi

if [[ ! -d "$KNOWLEDGE_DIR" ]]; then
  log_error "Knowledge directory not found: $KNOWLEDGE_DIR"
  exit 1
fi

# --- Build search terms ---

# Split tags into newline-separated list
tag_list=""
if [[ -n "$TAGS" ]]; then
  tag_list=$(echo "$TAGS" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')
fi

# Extract keywords from title (lowercase, strip common words)
title_keywords=""
if [[ -n "$TITLE" ]]; then
  stop_words=" the a an in on at to for of is are was were be been being with from by and or not "
  for word in $TITLE; do
    word_lower=$(echo "$word" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
    [[ ${#word_lower} -lt 3 ]] && continue
    # Check if stop word
    if echo "$stop_words" | grep -q " ${word_lower} "; then
      continue
    fi
    title_keywords="${title_keywords}${word_lower}"$'\n'
  done
  title_keywords=$(echo "$title_keywords" | grep -v '^$' | sort -u)
fi

# --- Score each knowledge entry using temp file ---

SCORE_FILE=$(mktemp)
trap "rm -f '$SCORE_FILE'" EXIT

# Score each file (use process substitution to avoid subshell issues with pipefail)
while IFS= read -r kfile; do
  [[ -z "$kfile" ]] && continue

  score=0
  matched=""

  content=$(cat "$kfile" 2>/dev/null) || continue

  # Skip entries without a title field (e.g., repo listings)
  echo "$content" | grep -q "^title:" || continue

  # Score by tag overlap
  if [[ -n "$tag_list" ]]; then
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      if echo "$content" | grep -qi "tags:.*${tag}"; then
        score=$((score + 3))
        matched="${matched}${tag},"
      fi
      if echo "$content" | grep -qi "codebase_type:.*${tag}"; then
        score=$((score + 2))
        matched="${matched}${tag}(codebase),"
      fi
      if echo "$content" | grep -qi "platform:.*${tag}"; then
        score=$((score + 2))
        matched="${matched}${tag}(platform),"
      fi
    done <<< "$tag_list"
  fi

  # Score by title keyword matches
  if [[ -n "$title_keywords" ]]; then
    entry_title=$(echo "$content" | grep "^title:" | head -1 | cut -d: -f2- | xargs)
    while IFS= read -r keyword; do
      [[ -z "$keyword" ]] && continue
      if echo "$content" | grep -qi "$keyword"; then
        score=$((score + 1))
      fi
      if echo "$entry_title" | grep -qi "$keyword"; then
        score=$((score + 2))
      fi
    done <<< "$title_keywords"
  fi

  if [[ $score -gt 0 ]]; then
    entry_title=$(echo "$content" | grep "^title:" | head -1 | cut -d: -f2- | xargs)
    # Format: score|file|matched_tags|title
    echo "${score}|${kfile}|${matched%,}|${entry_title}" >> "$SCORE_FILE"
  fi
done < <(find "$KNOWLEDGE_DIR" -name "*.yaml" -type f 2>/dev/null)

# --- Rank and limit results ---

if [[ ! -s "$SCORE_FILE" ]]; then
  if [[ "$FORMAT" == "paths" ]]; then
    exit 0
  elif [[ "$FORMAT" == "yaml" ]]; then
    echo "matched_entries: []"
  fi
  exit 0
fi

# Sort by score descending, limit results
ranked=$(sort -t'|' -k1 -nr "$SCORE_FILE" | head -n "$MAX_RESULTS")

# --- Output ---

case "$FORMAT" in
  paths)
    echo "$ranked" | while IFS='|' read -r score file matched title; do
      echo "$file"
    done
    ;;

  yaml)
    echo "matched_entries:"
    echo "$ranked" | while IFS='|' read -r score file matched title; do
      entry_id=$(yaml_get "$file" "id" 2>/dev/null || basename "$file" .yaml)
      category=$(basename "$(dirname "$file")")
      echo "  - id: \"$entry_id\""
      echo "    title: \"$title\""
      echo "    category: \"$category\""
      echo "    score: $score"
      echo "    matched_tags: \"$matched\""
      echo "    path: \"$file\""
    done
    ;;

  markdown)
    echo "## Rally Tavern Knowledge — Relevant Entries"
    echo ""
    echo "The following knowledge entries were matched for your current task."
    echo "Review these before starting — they contain lessons, practices, and"
    echo "solutions from prior work that may save you time or prevent mistakes."
    echo ""

    echo "$ranked" | while IFS='|' read -r score file matched title; do
      category=$(basename "$(dirname "$file")")

      echo "### ${title} (${category})"
      echo ""

      # Extract key fields — yaml_get only gets single-line values;
      # for multiline (|), grab the indented block that follows
      summary=$(yaml_get "$file" "summary" 2>/dev/null || true)
      lesson=$(yaml_get "$file" "lesson" 2>/dev/null || true)

      # If value is "|" (multiline indicator), extract the indented block
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

      # Extract stop/start if postmortem
      stop=$(sed -n '/^stop:/,/^[a-z]/p' "$file" 2>/dev/null | grep "^  -" | head -3 || true)
      start=$(sed -n '/^start:/,/^[a-z]/p' "$file" 2>/dev/null | grep "^  -" | head -3 || true)
      if [[ -n "$stop" ]] || [[ -n "$start" ]]; then
        if [[ -n "$stop" ]]; then
          echo "**Stop doing:**"
          echo "$stop"
          echo ""
        fi
        if [[ -n "$start" ]]; then
          echo "**Start doing:**"
          echo "$start"
          echo ""
        fi
      fi

      echo "---"
      echo ""
    done
    ;;

  *)
    log_error "Unknown format: $FORMAT"
    exit 1
    ;;
esac
