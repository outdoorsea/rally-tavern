#!/bin/bash
# Rally Feedback — Feedback Loop Engine (Feature 16)
# Aggregates build receipts and identifies improvement opportunities.
#
# Usage:
#   rally-feedback.sh analyze [--project-dir <dir>] [--output <path>]
#   rally-feedback.sh summary [--project-dir <dir>]

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

RECEIPTS_DIR_NAME=".rally/receipts"

ACTION="${1:-help}"
shift 2>/dev/null || true

# --- Analyze ---

cmd_analyze() {
  local project_dir="." output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project-dir) project_dir="${2:-.}"; shift 2;;
      --output)      output="${2:-}"; shift 2;;
      --help|-h)
        echo "Usage: rally feedback analyze [--project-dir <dir>] [--output <path>]"
        exit 0
        ;;
      *) log_error "Unknown option: $1"; exit 1;;
    esac
  done

  local receipts_dir="${project_dir}/${RECEIPTS_DIR_NAME}"
  if [[ ! -d "$receipts_dir" ]]; then
    log_error "No receipts directory found: $receipts_dir"
    log_info "Run 'rally receipt generate' after builds to collect data."
    exit 1
  fi

  local receipt_files=()
  while IFS= read -r f; do
    [[ -f "$f" ]] && receipt_files+=("$f")
  done < <(ls -t "$receipts_dir"/*.yaml 2>/dev/null || true)

  if [[ ${#receipt_files[@]} -eq 0 ]]; then
    log_info "No receipts found in: $receipts_dir"
    exit 0
  fi

  local total_receipts=${#receipt_files[@]}

  # --- Aggregate metrics ---
  local total_commits=0 total_files_changed=0
  local total_lines_added=0 total_lines_deleted=0
  local total_files_added=0 total_files_modified=0 total_files_deleted=0

  # Track file type frequencies
  declare -A type_frequency

  # Track branches
  declare -A branch_frequency

  for receipt in "${receipt_files[@]}"; do
    # Commit counts
    local cc
    cc=$(grep "^  commit_count:" "$receipt" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo "0")
    total_commits=$((total_commits + cc))

    # File counts
    local tc fa fm fd
    tc=$(grep "^  total_changed:" "$receipt" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo "0")
    fa=$(grep "^  added:" "$receipt" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo "0")
    fm=$(grep "^  modified:" "$receipt" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo "0")
    fd=$(grep "^  deleted:" "$receipt" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo "0")
    total_files_changed=$((total_files_changed + tc))
    total_files_added=$((total_files_added + fa))
    total_files_modified=$((total_files_modified + fm))
    total_files_deleted=$((total_files_deleted + fd))

    # Line counts (the second occurrence of added/deleted is for lines)
    local la ld
    la=$(grep "^  added:" "$receipt" 2>/dev/null | sed -n '2p' | cut -d: -f2- | xargs || echo "0")
    ld=$(grep "^  deleted:" "$receipt" 2>/dev/null | sed -n '2p' | cut -d: -f2- | xargs || echo "0")
    [[ -z "$la" ]] && la=0
    [[ -z "$ld" ]] && ld=0
    total_lines_added=$((total_lines_added + la))
    total_lines_deleted=$((total_lines_deleted + ld))

    # File type frequency
    local in_by_type=false
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]+by_type: ]]; then
        in_by_type=true
        continue
      fi
      if $in_by_type; then
        if [[ "$line" =~ ^[[:space:]]+\"(\.[a-zA-Z0-9]+)\":[[:space:]]*([0-9]+) ]]; then
          local ext="${BASH_REMATCH[1]}"
          local cnt="${BASH_REMATCH[2]}"
          type_frequency["$ext"]=$(( ${type_frequency["$ext"]:-0} + cnt ))
        elif [[ "$line" =~ ^[a-z] ]]; then
          break
        fi
      fi
    done < "$receipt"

    # Branch frequency
    local branch
    branch=$(grep "^  branch:" "$receipt" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo "unknown")
    branch_frequency["$branch"]=$(( ${branch_frequency["$branch"]:-0} + 1 ))
  done

  # --- Compute averages ---
  local avg_commits avg_files avg_lines_added avg_lines_deleted
  if [[ $total_receipts -gt 0 ]]; then
    avg_commits=$((total_commits / total_receipts))
    avg_files=$((total_files_changed / total_receipts))
    avg_lines_added=$((total_lines_added / total_receipts))
    avg_lines_deleted=$((total_lines_deleted / total_receipts))
  else
    avg_commits=0
    avg_files=0
    avg_lines_added=0
    avg_lines_deleted=0
  fi

  # --- Identify patterns ---

  # Most common file types
  local sorted_types=""
  for ext in "${!type_frequency[@]}"; do
    sorted_types="${sorted_types}${type_frequency[$ext]}|${ext}\n"
  done
  sorted_types=$(echo -e "$sorted_types" | sort -t'|' -k1 -nr | head -10)

  # --- Generate recommendations ---
  local recommendations=()

  # Large average change sets suggest missing components
  if [[ $avg_files -gt 20 ]]; then
    recommendations+=("High average file churn ($avg_files files/build). Consider extracting reusable components.")
  fi

  # High delete ratio suggests refactoring cycles
  if [[ $total_lines_deleted -gt 0 ]] && [[ $total_lines_added -gt 0 ]]; then
    local delete_ratio=$((total_lines_deleted * 100 / total_lines_added))
    if [[ $delete_ratio -gt 50 ]]; then
      recommendations+=("High delete-to-add ratio (${delete_ratio}%). Frequent rewrites may indicate unclear requirements or missing architecture review.")
    fi
  fi

  # Many small commits suggest good hygiene
  if [[ $avg_commits -gt 0 ]] && [[ $avg_commits -le 3 ]]; then
    recommendations+=("Good: Average commit count is low ($avg_commits/build), suggesting focused changes.")
  fi

  # Repeated file type patterns
  for ext in "${!type_frequency[@]}"; do
    if [[ "${type_frequency[$ext]}" -gt $((total_receipts * 3)) ]]; then
      recommendations+=("File type '$ext' appears frequently (${type_frequency[$ext]} changes across $total_receipts builds). Consider templating or component extraction for this type.")
    fi
  done

  # --- Output ---
  local generated_at
  generated_at=$(timestamp)
  output="${output:-${project_dir}/.rally/feedback-analysis.yaml}"
  mkdir -p "$(dirname "$output")"

  {
    echo "schema_version: 1"
    echo "generated_at: \"$generated_at\""
    echo "receipts_analyzed: $total_receipts"
    echo ""
    echo "# Aggregate metrics across all receipts"
    echo "totals:"
    echo "  commits: $total_commits"
    echo "  files_changed: $total_files_changed"
    echo "  files_added: $total_files_added"
    echo "  files_modified: $total_files_modified"
    echo "  files_deleted: $total_files_deleted"
    echo "  lines_added: $total_lines_added"
    echo "  lines_deleted: $total_lines_deleted"
    echo "  lines_net: $((total_lines_added - total_lines_deleted))"
    echo ""
    echo "averages:"
    echo "  commits_per_build: $avg_commits"
    echo "  files_per_build: $avg_files"
    echo "  lines_added_per_build: $avg_lines_added"
    echo "  lines_deleted_per_build: $avg_lines_deleted"
    echo ""
    echo "# Most frequently changed file types"
    echo "file_type_frequency:"
    if [[ -n "$sorted_types" ]]; then
      while IFS='|' read -r count ext; do
        [[ -z "$ext" ]] && continue
        echo "  \"$ext\": $count"
      done <<< "$sorted_types"
    else
      echo "  {}"
    fi
    echo ""
    echo "# Improvement recommendations"
    echo "recommendations:"
    if [[ ${#recommendations[@]} -eq 0 ]]; then
      echo "  - \"Insufficient data for recommendations. Collect more build receipts.\""
    else
      for rec in "${recommendations[@]}"; do
        echo "  - \"$rec\""
      done
    fi
    echo ""
    echo "# Suggested actions"
    echo "suggested_actions:"
    echo "  extract_components: []"
    echo "  refine_skills: []"
    echo "  update_defaults: []"
  } > "$output"

  log_success "Feedback analysis generated: $output"
  log_info "  Receipts analyzed: $total_receipts"
  log_info "  Total commits: $total_commits"
  log_info "  Recommendations: ${#recommendations[@]}"

  echo "$output"
}

# --- Summary ---

cmd_summary() {
  local project_dir="."

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project-dir) project_dir="${2:-.}"; shift 2;;
      --help|-h)
        echo "Usage: rally feedback summary [--project-dir <dir>]"
        exit 0
        ;;
      *) log_error "Unknown option: $1"; exit 1;;
    esac
  done

  local analysis_file="${project_dir}/.rally/feedback-analysis.yaml"
  if [[ ! -f "$analysis_file" ]]; then
    log_info "No feedback analysis found. Run 'rally feedback analyze' first."
    exit 0
  fi

  local receipts_analyzed total_commits total_files avg_commits avg_files
  receipts_analyzed=$(yaml_get "$analysis_file" "receipts_analyzed")
  total_commits=$(grep "^  commits:" "$analysis_file" | head -1 | cut -d: -f2- | xargs)
  total_files=$(grep "^  files_changed:" "$analysis_file" | head -1 | cut -d: -f2- | xargs)
  avg_commits=$(grep "^  commits_per_build:" "$analysis_file" | head -1 | cut -d: -f2- | xargs)
  avg_files=$(grep "^  files_per_build:" "$analysis_file" | head -1 | cut -d: -f2- | xargs)

  echo "📊 Feedback Analysis Summary"
  echo ""
  echo "  Builds analyzed:     ${receipts_analyzed:-0}"
  echo "  Total commits:       ${total_commits:-0}"
  echo "  Total files changed: ${total_files:-0}"
  echo "  Avg commits/build:   ${avg_commits:-0}"
  echo "  Avg files/build:     ${avg_files:-0}"
  echo ""

  echo "  Recommendations:"
  local in_recs=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^recommendations: ]]; then
      in_recs=true
      continue
    fi
    if $in_recs; then
      if [[ "$line" =~ ^[a-z] ]]; then
        break
      fi
      if [[ "$line" =~ ^[[:space:]]+- ]]; then
        local rec
        rec=$(echo "$line" | sed 's/^[[:space:]]*- //' | sed 's/^"//' | sed 's/"$//')
        echo "    - $rec"
      fi
    fi
  done < "$analysis_file"
}

# --- Help ---

cmd_help() {
  echo "Rally Feedback — Feedback Loop Engine"
  echo ""
  echo "Usage: rally feedback <action> [args...]"
  echo ""
  echo "Actions:"
  echo "  analyze    Aggregate receipts and identify improvement patterns"
  echo "  summary    Display feedback analysis summary"
  echo "  help       Show this help"
  echo ""
  echo "Examples:"
  echo "  rally feedback analyze"
  echo "  rally feedback analyze --project-dir ./myproject --output feedback.yaml"
  echo "  rally feedback summary"
}

# --- Dispatch ---

case "$ACTION" in
  analyze) cmd_analyze "$@";;
  summary) cmd_summary "$@";;
  help|--help|-h) cmd_help;;
  *)
    log_error "Unknown action: $ACTION"
    cmd_help
    exit 1
    ;;
esac
