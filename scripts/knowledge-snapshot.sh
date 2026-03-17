#!/bin/bash
# Knowledge Snapshot — Serialize all knowledge entries into a single JSON file
#
# This decouples search from filesystem presence of rally_tavern.
# Consumers (e.g., gastown's gt rally lookup) can fall back to the snapshot
# when the YAML knowledge directory isn't available.
#
# Usage:
#   knowledge-snapshot.sh                    # Generate snapshot to stdout
#   knowledge-snapshot.sh --output FILE      # Write to file
#   knowledge-snapshot.sh --cache            # Write to $GT_ROOT/.cache/
#   knowledge-snapshot.sh --check            # Verify snapshot is current
#
# The snapshot is a JSON file containing all non-deprecated knowledge entries
# with metadata for cache validation.

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

OUTPUT=""
CACHE_MODE=false
CHECK_MODE=false
KNOWLEDGE_DIR="$TAVERN_ROOT/knowledge"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output|-o) OUTPUT="${2:-}"; shift 2;;
    --cache)     CACHE_MODE=true; shift;;
    --check)     CHECK_MODE=true; shift;;
    --help|-h)
      echo "Knowledge Snapshot — Serialize knowledge entries to JSON"
      echo ""
      echo "Usage: knowledge-snapshot.sh [options]"
      echo ""
      echo "Options:"
      echo "  --output FILE   Write snapshot to FILE (default: stdout)"
      echo "  --cache         Write to \$GT_ROOT/.cache/rally-knowledge-snapshot.json"
      echo "  --check         Verify existing snapshot is current (exit 0=current, 1=stale)"
      echo ""
      echo "The snapshot contains all knowledge entries from practices/, solutions/,"
      echo "learned/, and postmortems/ in a format ready for consumption by gastown."
      exit 0
      ;;
    *) log_error "Unknown option: $1"; exit 1;;
  esac
done

# --- Resolve output path for --cache mode ---

if $CACHE_MODE; then
  GT_ROOT=""
  if [[ -n "${GT_ROOT_DIR:-}" ]]; then
    GT_ROOT="$GT_ROOT_DIR"
  else
    candidate="$(dirname "$TAVERN_ROOT")"
    if [[ -d "$candidate/.dolt-data" ]] || [[ -d "$candidate/mayor" ]] || [[ -f "$candidate/CLAUDE.md" ]]; then
      GT_ROOT="$candidate"
    fi
  fi

  if [[ -z "$GT_ROOT" ]]; then
    log_error "Cannot determine GT_ROOT for cache mode. Set GT_ROOT_DIR env var."
    exit 1
  fi

  mkdir -p "$GT_ROOT/.cache"
  OUTPUT="$GT_ROOT/.cache/rally-knowledge-snapshot.json"
fi

# --- Check mode: compare snapshot hash with current knowledge ---

if $CHECK_MODE; then
  SNAPSHOT_FILE="${OUTPUT:-$TAVERN_ROOT/knowledge/snapshot.json}"
  if [[ ! -f "$SNAPSHOT_FILE" ]]; then
    log_error "No snapshot found at $SNAPSHOT_FILE"
    exit 1
  fi

  current_hash=$(find "$KNOWLEDGE_DIR" -name "*.yaml" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
  snapshot_hash=$(grep '"source_hash"' "$SNAPSHOT_FILE" 2>/dev/null | head -1 | sed 's/.*"source_hash"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

  if [[ "$current_hash" == "$snapshot_hash" ]]; then
    log_success "Snapshot is current (hash: ${current_hash:0:12}...)"
    exit 0
  else
    log_warn "Snapshot is stale"
    log_info "  Current: ${current_hash:0:12}..."
    log_info "  Snapshot: ${snapshot_hash:0:12}..."
    exit 1
  fi
fi

# --- Generate snapshot ---

if [[ ! -d "$KNOWLEDGE_DIR" ]]; then
  log_error "Knowledge directory not found: $KNOWLEDGE_DIR"
  exit 1
fi

source_hash=$(find "$KNOWLEDGE_DIR" -name "*.yaml" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | shasum -a 256 | cut -d' ' -f1)

# --- JSON helper functions ---

# Escape a string for JSON embedding
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"     # backslash
  s="${s//\"/\\\"}"     # double quote
  s="$(printf '%s' "$s" | tr '\n' '\036' | sed 's/\x1e/\\n/g')"  # newline
  s="${s//$'\t'/\\t}"   # tab
  printf '%s' "$s"
}

# Parse a YAML list field like "tags: [a, b, c]" into a JSON array
yaml_list_to_json() {
  local file="$1" key="$2"
  local raw
  raw=$(grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}:[[:space:]]*//" || true)

  if [[ -z "$raw" ]]; then
    echo "[]"
    return
  fi

  # Strip brackets and split on comma
  raw=$(echo "$raw" | sed 's/\[//g;s/\]//g')
  local items=()
  while IFS= read -r item; do
    item=$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -z "$item" ]] && continue
    items+=("\"$(json_escape "$item")\"")
  done <<< "$(echo "$raw" | tr ',' '\n')"

  if [[ ${#items[@]} -eq 0 ]]; then
    echo "[]"
  else
    local IFS=','
    echo "[${items[*]}]"
  fi
}

# Parse YAML block list (lines starting with "  - ") into JSON array
yaml_block_list_to_json() {
  local file="$1" key="$2"
  local items=()
  local in_block=false

  while IFS= read -r line; do
    if [[ "$line" =~ ^${key}: ]]; then
      in_block=true
      continue
    fi
    if $in_block; then
      if [[ "$line" =~ ^[[:space:]][[:space:]]- ]]; then
        local val="${line#*- }"
        items+=("\"$(json_escape "$val")\"")
      elif [[ "$line" =~ ^[a-z] ]]; then
        break
      fi
    fi
  done < "$file"

  if [[ ${#items[@]} -eq 0 ]]; then
    echo "[]"
  else
    local IFS=','
    echo "[${items[*]}]"
  fi
}

# Extract multiline YAML value (handles both inline and block scalar)
extract_multiline() {
  local file="$1" key="$2"
  local value
  value=$(yaml_get "$file" "$key")

  if [[ "$value" == "|" ]] || [[ -z "$value" && $(grep -c "^${key}:" "$file" 2>/dev/null) -gt 0 ]]; then
    value=$(sed -n "/^${key}:/,/^[a-z]/p" "$file" 2>/dev/null | grep "^  " | sed 's/^  //' | head -20 || true)
  fi
  echo "$value"
}

# --- Emit a single knowledge entry as JSON ---

emit_entry() {
  local file="$1"
  local kind="$2"
  local content

  content=$(cat "$file" 2>/dev/null) || return 1

  # Skip files without a title
  echo "$content" | grep -q "^title:" || return 1

  # Skip deprecated entries
  if echo "$content" | grep -q "^deprecated: true"; then
    return 1
  fi

  local id title summary details codebase_type contributed_by created_at
  local problem solution context lesson last_verified superseded_by

  id=$(yaml_get "$file" "id")
  title=$(yaml_get "$file" "title")
  summary=$(extract_multiline "$file" "summary")
  details=$(extract_multiline "$file" "details")
  codebase_type=$(yaml_get "$file" "codebase_type")
  contributed_by=$(yaml_get "$file" "contributed_by")
  created_at=$(yaml_get "$file" "created_at")
  last_verified=$(yaml_get "$file" "last_verified")
  superseded_by=$(yaml_get "$file" "superseded_by")

  problem=$(extract_multiline "$file" "problem")
  solution=$(extract_multiline "$file" "solution")
  context=$(yaml_get "$file" "context")
  lesson=$(extract_multiline "$file" "lesson")

  local tags_json verified_json gotchas_json
  tags_json=$(yaml_list_to_json "$file" "tags")
  verified_json=$(yaml_list_to_json "$file" "verified_by")
  gotchas_json=$(yaml_block_list_to_json "$file" "gotchas")

  # Build JSON object
  local fields=()
  fields+=("\"id\":\"$(json_escape "$id")\"")
  fields+=("\"kind\":\"$kind\"")
  fields+=("\"title\":\"$(json_escape "$title")\"")
  fields+=("\"summary\":\"$(json_escape "$summary")\"")
  [[ -n "$details" ]] && fields+=("\"details\":\"$(json_escape "$details")\"")
  fields+=("\"tags\":$tags_json")
  [[ -n "$codebase_type" ]] && fields+=("\"codebase_type\":\"$(json_escape "$codebase_type")\"")
  [[ -n "$contributed_by" ]] && fields+=("\"contributed_by\":\"$(json_escape "$contributed_by")\"")
  [[ -n "$created_at" ]] && fields+=("\"created_at\":\"$(json_escape "$created_at")\"")
  fields+=("\"verified_by\":$verified_json")
  [[ -n "$last_verified" ]] && fields+=("\"last_verified\":\"$(json_escape "$last_verified")\"")
  [[ -n "$superseded_by" ]] && fields+=("\"superseded_by\":\"$(json_escape "$superseded_by")\"")
  [[ -n "$problem" ]] && fields+=("\"problem\":\"$(json_escape "$problem")\"")
  [[ -n "$solution" ]] && fields+=("\"solution\":\"$(json_escape "$solution")\"")
  [[ -n "$context" ]] && fields+=("\"context\":\"$(json_escape "$context")\"")
  [[ -n "$lesson" ]] && fields+=("\"lesson\":\"$(json_escape "$lesson")\"")
  fields+=("\"gotchas\":$gotchas_json")

  # Join fields with commas
  local json="{"
  local first=true
  for f in "${fields[@]}"; do
    if $first; then
      json+="$f"
      first=false
    else
      json+=",$f"
    fi
  done
  json+="}"

  echo "$json"
}

# --- Categories to snapshot ---
categories=(
  "practices:practice"
  "solutions:solution"
  "learned:learned"
  "postmortems:postmortem"
)

# --- Generate the snapshot ---

TEMP_FILE=$(mktemp)
trap "rm -f '$TEMP_FILE'" EXIT

{
  printf '{\n'
  printf '  "version": 1,\n'
  printf '  "generated_at": "%s",\n' "$(timestamp)"
  printf '  "source_hash": "%s",\n' "$source_hash"

  # Collect all entries
  all_entries=()
  for cat_pair in "${categories[@]}"; do
    dir="${cat_pair%%:*}"
    kind="${cat_pair##*:}"
    cat_dir="$KNOWLEDGE_DIR/$dir"

    [[ -d "$cat_dir" ]] || continue

    while IFS= read -r kfile; do
      [[ -z "$kfile" ]] && continue
      entry=$(emit_entry "$kfile" "$kind" 2>/dev/null) || continue
      [[ -z "$entry" ]] && continue
      all_entries+=("$entry")
    done < <(find "$cat_dir" -name "*.yaml" -type f 2>/dev/null | sort)
  done

  printf '  "entry_count": %d,\n' "${#all_entries[@]}"
  printf '  "entries": [\n'

  for i in "${!all_entries[@]}"; do
    if [[ $i -lt $((${#all_entries[@]} - 1)) ]]; then
      printf '    %s,\n' "${all_entries[$i]}"
    else
      printf '    %s\n' "${all_entries[$i]}"
    fi
  done

  printf '  ]\n'
  printf '}\n'
} > "$TEMP_FILE"

if [[ -n "$OUTPUT" ]]; then
  cp "$TEMP_FILE" "$OUTPUT"
  log_success "Snapshot written to $OUTPUT (${#all_entries[@]} entries, hash: ${source_hash:0:12}...)" >&2
else
  cat "$TEMP_FILE"
fi
