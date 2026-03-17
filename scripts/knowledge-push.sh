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

USE_SNAPSHOT=false
SNAPSHOT_FILE=""

if [[ ! -d "$KNOWLEDGE_DIR" ]]; then
  # Fallback: check for snapshot in known locations
  for candidate in \
    "$TAVERN_ROOT/knowledge/snapshot.json" \
    "${GT_ROOT_DIR:-$TAVERN_ROOT/..}/.cache/rally-knowledge-snapshot.json"; do
    if [[ -f "$candidate" ]]; then
      SNAPSHOT_FILE="$candidate"
      USE_SNAPSHOT=true
      break
    fi
  done

  if ! $USE_SNAPSHOT; then
    log_error "Knowledge directory not found and no snapshot available: $KNOWLEDGE_DIR"
    exit 1
  fi
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

if $USE_SNAPSHOT; then
  # --- Snapshot-based search: use Python to query the JSON snapshot ---
  python3 -c "
import json, sys

snapshot = json.load(open('$SNAPSHOT_FILE'))
tag_list = [t.strip() for t in '''$TAGS'''.split(',') if t.strip()] if '''$TAGS''' else []
title_keywords = [k for k in '''$title_keywords'''.split('\n') if k.strip()]

for entry in snapshot.get('entries', []):
    score = 0
    matched = []

    # Tag overlap scoring
    entry_tags = [t.lower() for t in entry.get('tags', [])]
    codebase = (entry.get('codebase_type', '') or '').lower()

    for tag in tag_list:
        tl = tag.lower()
        if tl in entry_tags:
            score += 3
            matched.append(tag)
        if codebase and tl in codebase:
            score += 2
            matched.append(f'{tag}(codebase)')

    # Title keyword scoring
    entry_title = (entry.get('title', '') or '').lower()
    all_text = ' '.join(str(v) for v in entry.values() if isinstance(v, str)).lower()
    for kw in title_keywords:
        if not kw:
            continue
        if kw in all_text:
            score += 1
        if kw in entry_title:
            score += 2

    if score > 0:
        # Format: score|source|matched_tags|title
        src = f'snapshot:{entry[\"id\"]}'
        print(f'{score}|{src}|{\",\".join(matched)}|{entry.get(\"title\",\"\")}')
" >> "$SCORE_FILE" 2>/dev/null

else
  # --- Filesystem-based search: scan YAML files directly ---
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

    # 3. Verification bonus/penalty
    verified_by=$(echo "$content" | grep "^verified_by:" | head -1 | cut -d: -f2- | xargs || true)
    if [[ -n "$verified_by" ]] && [[ "$verified_by" != "[]" ]]; then
      score=$((score + 3))
    else
      # Penalize unverified entries
      score=$((score - 2))
    fi

    # 4. Time decay — penalize old entries
    created_at=$(echo "$content" | grep "^created_at:" | head -1 | cut -d: -f2- | xargs || true)
    if [[ -n "$created_at" ]]; then
      # Extract date portion (YYYY-MM-DD) from ISO timestamp
      created_date="${created_at%%T*}"
      # Calculate age in days using epoch seconds
      if created_epoch=$(date -j -f "%Y-%m-%d" "$created_date" "+%s" 2>/dev/null); then
        now_epoch=$(date "+%s")
        age_days=$(( (now_epoch - created_epoch) / 86400 ))
        # Decay: -1 point per 30 days of age, capped at -5
        if [[ $age_days -gt 0 ]]; then
          decay=$(( age_days / 30 ))
          [[ $decay -gt 5 ]] && decay=5
          score=$((score - decay))
        fi
      fi
    fi

    if [[ $score -gt 0 ]]; then
      entry_title=$(echo "$content" | grep "^title:" | head -1 | cut -d: -f2- | xargs)
      # Format: score|file|matched_tags|title
      echo "${score}|${kfile}|${matched%,}|${entry_title}" >> "$SCORE_FILE"
    fi
  done < <(find "$KNOWLEDGE_DIR" -name "*.yaml" -type f 2>/dev/null)
fi

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

# --- Snapshot field extraction helpers ---

# Extract a string field from snapshot entry by ID
_snapshot_field() {
  local entry_id="$1" field="$2"
  python3 -c "
import json, sys
data = json.load(open('$SNAPSHOT_FILE'))
for e in data.get('entries', []):
    if e.get('id') == '$entry_id':
        val = e.get('$field', '')
        if val:
            print(val.replace('\\\\n', '\n') if isinstance(val, str) else str(val))
        break
" 2>/dev/null || true
}

# Extract a list field from snapshot entry by ID (one item per line, prefixed with "  - ")
_snapshot_list() {
  local entry_id="$1" field="$2"
  python3 -c "
import json
data = json.load(open('$SNAPSHOT_FILE'))
for e in data.get('entries', []):
    if e.get('id') == '$entry_id':
        items = e.get('$field', [])
        for item in items:
            print(f'  - {item}')
        break
" 2>/dev/null || true
}

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
      if [[ "$file" == snapshot:* ]]; then
        entry_id="${file#snapshot:}"
        category=$(_snapshot_field "$entry_id" "kind")
      else
        entry_id=$(yaml_get "$file" "id" 2>/dev/null || basename "$file" .yaml)
        category=$(basename "$(dirname "$file")")
      fi
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
      if [[ "$file" == snapshot:* ]]; then
        # --- Snapshot-based entry rendering ---
        entry_id="${file#snapshot:}"
        category=$(_snapshot_field "$entry_id" "kind")

        echo "### ${title} (${category})"
        echo ""

        summary=$(_snapshot_field "$entry_id" "summary")
        lesson=$(_snapshot_field "$entry_id" "lesson")

        if [[ -n "$summary" ]]; then
          echo "$summary"
          echo ""
        fi
        if [[ -n "$lesson" ]]; then
          echo "**Lesson:** $lesson"
          echo ""
        fi

        gotchas=$(_snapshot_list "$entry_id" "gotchas")
        if [[ -n "$gotchas" ]]; then
          echo "**Gotchas:**"
          echo "$gotchas"
          echo ""
        fi
      else
        # --- Filesystem-based entry rendering ---
        category=$(basename "$(dirname "$file")")

        echo "### ${title} (${category})"
        echo ""

        summary=$(yaml_get "$file" "summary" 2>/dev/null || true)
        lesson=$(yaml_get "$file" "lesson" 2>/dev/null || true)

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

        gotchas=$(sed -n '/^gotchas:/,/^[a-z]/p' "$file" 2>/dev/null | grep "^  -" | head -5 || true)
        if [[ -n "$gotchas" ]]; then
          echo "**Gotchas:**"
          echo "$gotchas"
          echo ""
        fi

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
