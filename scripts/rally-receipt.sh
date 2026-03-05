#!/bin/bash
# Rally Receipt — Build Receipt System (Feature 15)
# Post-build feedback capture: collects metrics from git, build, and tests.
#
# Usage:
#   rally-receipt.sh generate [--project-dir <dir>] [--build-card <path>] [--profile <path>] [--output <path>] [--base-branch <branch>]
#   rally-receipt.sh show <receipt-path>
#   rally-receipt.sh history [--project-dir <dir>] [--limit N]

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

RECEIPTS_DIR_NAME=".rally/receipts"

ACTION="${1:-help}"
shift 2>/dev/null || true

# --- Generate ---

cmd_generate() {
  local project_dir="." build_card="" profile="" output="" base_branch="main"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project-dir) project_dir="${2:-.}"; shift 2;;
      --build-card)  build_card="${2:-}"; shift 2;;
      --profile)     profile="${2:-}"; shift 2;;
      --output)      output="${2:-}"; shift 2;;
      --base-branch) base_branch="${2:-main}"; shift 2;;
      --help|-h)
        echo "Usage: rally receipt generate [options]"
        echo ""
        echo "Options:"
        echo "  --project-dir <dir>    Project directory (default: .)"
        echo "  --build-card <path>    Path to build-card.yaml (optional)"
        echo "  --profile <path>       Path to project-profile.yaml (optional)"
        echo "  --output <path>        Output receipt path (default: .rally/receipts/<id>.yaml)"
        echo "  --base-branch <branch> Base branch for diff (default: main)"
        exit 0
        ;;
      *) log_error "Unknown option: $1"; exit 1;;
    esac
  done

  cd "$project_dir"

  local receipt_id
  receipt_id=$(generate_id "receipt")
  local generated_at
  generated_at=$(timestamp)

  # --- Git metrics ---
  local branch commit_range commit_count
  branch=$(git branch --show-current 2>/dev/null || echo "unknown")

  # Find commit range vs base branch
  local merge_base
  merge_base=$(git merge-base "origin/${base_branch}" HEAD 2>/dev/null || git merge-base "${base_branch}" HEAD 2>/dev/null || echo "")

  if [[ -n "$merge_base" ]]; then
    local head_sha
    head_sha=$(git rev-parse HEAD)
    commit_range="${merge_base:0:8}..${head_sha:0:8}"
    commit_count=$(git rev-list "${merge_base}..HEAD" --count 2>/dev/null || echo "0")
  else
    commit_range=""
    commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
  fi

  # --- File metrics ---
  local files_added=0 files_modified=0 files_deleted=0 total_changed=0
  local lines_added=0 lines_deleted=0

  if [[ -n "$merge_base" ]]; then
    # Count file changes
    files_added=$(git diff --diff-filter=A --name-only "${merge_base}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
    files_modified=$(git diff --diff-filter=M --name-only "${merge_base}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
    files_deleted=$(git diff --diff-filter=D --name-only "${merge_base}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
    total_changed=$((files_added + files_modified + files_deleted))

    # Count line changes
    local diff_stat
    diff_stat=$(git diff --shortstat "${merge_base}..HEAD" 2>/dev/null || echo "")
    if [[ -n "$diff_stat" ]]; then
      lines_added=$(echo "$diff_stat" | grep -o '[0-9]* insertion' | grep -o '[0-9]*' || echo "0")
      lines_deleted=$(echo "$diff_stat" | grep -o '[0-9]* deletion' | grep -o '[0-9]*' || echo "0")
    fi
  fi

  [[ -z "$lines_added" ]] && lines_added=0
  [[ -z "$lines_deleted" ]] && lines_deleted=0
  local lines_net=$((lines_added - lines_deleted))

  # --- File types breakdown ---
  local by_type_yaml=""
  if [[ -n "$merge_base" ]]; then
    local ext_counts
    ext_counts=$(git diff --name-only "${merge_base}..HEAD" 2>/dev/null | sed 's/.*\./\./' | sort | uniq -c | sort -rn || echo "")
    if [[ -n "$ext_counts" ]]; then
      by_type_yaml=""
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local count ext
        count=$(echo "$line" | awk '{print $1}')
        ext=$(echo "$line" | awk '{print $2}')
        by_type_yaml="${by_type_yaml}    \"${ext}\": ${count}\n"
      done <<< "$ext_counts"
    fi
  fi

  # --- Project info ---
  local project_name=""
  if [[ -n "$profile" ]] && [[ -f "$profile" ]]; then
    project_name=$(yaml_get "$profile" "  name" 2>/dev/null || echo "")
  fi
  [[ -z "$project_name" ]] && project_name=$(basename "$(pwd)")

  # --- Skills used (from build card) ---
  local skills_yaml=""
  if [[ -n "$build_card" ]] && [[ -f "$build_card" ]]; then
    local completed
    completed=$(grep "^  - " "$build_card" 2>/dev/null | head -20 || echo "")
    if grep -q "^completed_sections:" "$build_card" 2>/dev/null; then
      skills_yaml=$(awk '/^completed_sections:/{flag=1; next} /^[a-z]/{flag=0} flag && /^  - /' "$build_card" 2>/dev/null | sed 's/^  - /  - /' || echo "")
    fi
  fi

  # --- Output ---
  local receipts_dir="${project_dir}/${RECEIPTS_DIR_NAME}"
  mkdir -p "$receipts_dir"
  output="${output:-${receipts_dir}/${receipt_id}.yaml}"
  mkdir -p "$(dirname "$output")"

  {
    echo "schema_version: 1"
    echo "receipt_id: \"$receipt_id\""
    echo "generated_at: \"$generated_at\""
    echo ""
    echo "project:"
    echo "  name: \"$project_name\""
    echo "  profile_path: \"${profile:-}\""
    echo "  build_card_path: \"${build_card:-}\""
    echo ""
    echo "build:"
    echo "  branch: \"$branch\""
    echo "  base_branch: \"$base_branch\""
    echo "  commit_range: \"$commit_range\""
    echo "  commit_count: $commit_count"
    echo ""
    echo "files:"
    echo "  total_changed: $total_changed"
    echo "  added: $files_added"
    echo "  modified: $files_modified"
    echo "  deleted: $files_deleted"
    if [[ -n "$by_type_yaml" ]]; then
      echo "  by_type:"
      echo -e "$by_type_yaml"
    else
      echo "  by_type: {}"
    fi
    echo ""
    echo "lines:"
    echo "  added: $lines_added"
    echo "  deleted: $lines_deleted"
    echo "  net: $lines_net"
    echo ""
    echo "artifacts_used: []"
    echo ""
    echo "tests:"
    echo "  ran: false"
    echo "  passed: 0"
    echo "  failed: 0"
    echo "  skipped: 0"
    echo "  pass_rate: 0.0"
    echo ""
    echo "quality:"
    echo "  lint_clean: null"
    echo "  typecheck_clean: null"
    echo "  build_success: null"
    echo ""
    echo "skills_used:"
    if [[ -n "$skills_yaml" ]]; then
      echo "$skills_yaml"
    else
      echo "  []"
    fi
    echo ""
    echo "notes: \"\""
  } > "$output"

  log_success "Build receipt generated: $output"
  log_info "  Receipt ID: $receipt_id"
  log_info "  Branch: $branch"
  log_info "  Commits: $commit_count"
  log_info "  Files changed: $total_changed (+$lines_added/-$lines_deleted)"

  echo "$output"
}

# --- Show ---

cmd_show() {
  local receipt_path="${1:-}"
  [[ -z "$receipt_path" ]] && { log_error "Usage: rally receipt show <receipt-path>"; exit 1; }
  require_file "$receipt_path"

  local receipt_id generated_at project_name branch commit_count
  local total_changed lines_added lines_deleted

  receipt_id=$(yaml_get "$receipt_path" "receipt_id")
  generated_at=$(yaml_get "$receipt_path" "generated_at")
  project_name=$(grep "^  name:" "$receipt_path" | head -1 | cut -d: -f2- | xargs)
  branch=$(grep "^  branch:" "$receipt_path" | head -1 | cut -d: -f2- | xargs)
  commit_count=$(grep "^  commit_count:" "$receipt_path" | head -1 | cut -d: -f2- | xargs)
  total_changed=$(grep "^  total_changed:" "$receipt_path" | head -1 | cut -d: -f2- | xargs)
  lines_added=$(grep "^  added:" "$receipt_path" | sed -n '2p' | cut -d: -f2- | xargs)
  lines_deleted=$(grep "^  deleted:" "$receipt_path" | sed -n '2p' | cut -d: -f2- | xargs)

  echo "📋 Build Receipt: $receipt_id"
  echo "   Project: ${project_name:-unknown}"
  echo "   Generated: ${generated_at:-unknown}"
  echo "   Branch: ${branch:-unknown}"
  echo "   Commits: ${commit_count:-0}"
  echo "   Files changed: ${total_changed:-0} (+${lines_added:-0}/-${lines_deleted:-0})"
}

# --- History ---

cmd_history() {
  local project_dir="." limit=10

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project-dir) project_dir="${2:-.}"; shift 2;;
      --limit)       limit="${2:-10}"; shift 2;;
      --help|-h)
        echo "Usage: rally receipt history [--project-dir <dir>] [--limit N]"
        exit 0
        ;;
      *) log_error "Unknown option: $1"; exit 1;;
    esac
  done

  local receipts_dir="${project_dir}/${RECEIPTS_DIR_NAME}"
  if [[ ! -d "$receipts_dir" ]]; then
    log_info "No receipts found in: $receipts_dir"
    exit 0
  fi

  local count=0
  echo "📋 Build Receipt History"
  echo ""

  # Sort by modification time, newest first
  for receipt in $(ls -t "$receipts_dir"/*.yaml 2>/dev/null); do
    [[ $count -ge $limit ]] && break
    [[ -f "$receipt" ]] || continue

    local receipt_id generated_at branch commit_count total_changed
    receipt_id=$(yaml_get "$receipt" "receipt_id")
    generated_at=$(yaml_get "$receipt" "generated_at")
    branch=$(grep "^  branch:" "$receipt" | head -1 | cut -d: -f2- | xargs)
    commit_count=$(grep "^  commit_count:" "$receipt" | head -1 | cut -d: -f2- | xargs)
    total_changed=$(grep "^  total_changed:" "$receipt" | head -1 | cut -d: -f2- | xargs)

    echo "  ${generated_at:-unknown}  ${receipt_id:-unknown}  branch:${branch:-?}  commits:${commit_count:-0}  files:${total_changed:-0}"
    count=$((count + 1))
  done

  echo ""
  echo "  Total: $count receipt(s)"
}

# --- Help ---

cmd_help() {
  echo "Rally Receipt — Build Receipt System"
  echo ""
  echo "Usage: rally receipt <action> [args...]"
  echo ""
  echo "Actions:"
  echo "  generate   Capture post-build metrics from git"
  echo "  show       Display a specific receipt"
  echo "  history    List receipt history for a project"
  echo "  help       Show this help"
  echo ""
  echo "Examples:"
  echo "  rally receipt generate --base-branch main"
  echo "  rally receipt generate --build-card build-card.yaml --profile profile.yaml"
  echo "  rally receipt show .rally/receipts/receipt-abc12345.yaml"
  echo "  rally receipt history --limit 5"
}

# --- Dispatch ---

case "$ACTION" in
  generate) cmd_generate "$@";;
  show)     cmd_show "$@";;
  history)  cmd_history "$@";;
  help|--help|-h) cmd_help;;
  *)
    log_error "Unknown action: $ACTION"
    cmd_help
    exit 1
    ;;
esac
