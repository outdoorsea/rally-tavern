#!/bin/bash
# Rally Dispatch — Mayor Integration / Convoy Bridge (Feature 17)
# Converts build card execution plan into Gas Town beads grouped by convoy phase.
#
# Usage:
#   rally-dispatch.sh <build-card.yaml> [--tasks <tasks.yaml>] [--dry-run] [--output <dir>]
#
# The dispatcher reads task definitions (from rally-tasks.sh output) and creates
# beads organized by convoy phase with proper dependencies.

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

BUILD_CARD=""
TASKS_FILE=""
DRY_RUN=false
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tasks)    TASKS_FILE="${2:-}"; shift 2;;
    --dry-run)  DRY_RUN=true; shift;;
    --output)   OUTPUT_DIR="${2:-}"; shift 2;;
    --help|-h)
      echo "Rally Dispatch — Mayor Integration (Convoy Bridge)"
      echo ""
      echo "Usage: rally dispatch <build-card.yaml> [options]"
      echo ""
      echo "Options:"
      echo "  --tasks <tasks.yaml>  Path to generated tasks (default: auto-generate)"
      echo "  --dry-run             Preview beads without creating them"
      echo "  --output <dir>        Output directory for dispatch manifest"
      echo ""
      echo "Converts build card + tasks into Gas Town beads grouped by convoy phase."
      echo "Convoy ordering: PM → UX → Architecture → Test → Implementation"
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      exit 1
      ;;
    *)
      if [[ -z "$BUILD_CARD" ]]; then
        BUILD_CARD="$1"
      else
        log_error "Unexpected argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

[[ -z "$BUILD_CARD" ]] && { log_error "Usage: rally dispatch <build-card.yaml> [--tasks <tasks.yaml>]"; exit 1; }
require_file "$BUILD_CARD"

# --- If no tasks file, try to auto-generate ---
if [[ -z "$TASKS_FILE" ]]; then
  TASKS_FILE="${BUILD_CARD%.yaml}-tasks.yaml"
  if [[ ! -f "$TASKS_FILE" ]]; then
    log_info "No tasks file found. Generating from build card..."
    tasks_gen_script="$TAVERN_ROOT/scripts/rally-tasks.sh"
    if [[ -x "$tasks_gen_script" ]]; then
      set +e
      TASKS_FILE=$("$tasks_gen_script" generate "$BUILD_CARD" 2>/dev/null | tail -1)
      set -e
    fi
  fi
fi

if [[ ! -f "$TASKS_FILE" ]]; then
  log_error "Tasks file not found: $TASKS_FILE"
  log_info "Generate tasks first: rally tasks generate <build-card.yaml>"
  exit 1
fi

# --- Read build card metadata ---
dispatch_project_name=$(yaml_get "$BUILD_CARD" "project_name" 2>/dev/null || echo "unknown")

log_info "Dispatch — Convoy Bridge"
log_info "  Build card: $BUILD_CARD"
log_info "  Tasks: $TASKS_FILE"
log_info "  Project: $dispatch_project_name"

# --- Define convoy phases (order matters) ---
CONVOY_PHASES=(
  "pm:Product Management"
  "ux:UX Design"
  "architecture:Architecture"
  "security:Security"
  "test:Testing"
  "implementation:Implementation"
)

# --- Parse tasks file and group by category ---
declare -A phase_tasks
current_task_id=""
current_category=""
current_title=""
current_desc=""
current_complexity=""
task_count=0
in_tasks=false
in_task=false
in_deps=false
current_deps=""

while IFS= read -r line; do
  if [[ "$line" =~ ^tasks: ]]; then
    in_tasks=true
    continue
  fi

  if ! $in_tasks; then
    continue
  fi

  # New task item
  if [[ "$line" =~ ^[[:space:]]{2}-[[:space:]]id:[[:space:]]*(.*) ]]; then
    # Save previous task
    if [[ -n "$current_task_id" ]]; then
      entry="${current_task_id}|${current_title}|${current_desc}|${current_complexity}|${current_deps}"
      cat="${current_category:-implementation}"
      phase_tasks["$cat"]="${phase_tasks["$cat"]:-}${entry}"$'\n'
      task_count=$((task_count + 1))
    fi
    current_task_id=$(echo "${BASH_REMATCH[1]}" | xargs | tr -d '"')
    current_category=""
    current_title=""
    current_desc=""
    current_complexity="2"
    current_deps=""
    in_task=true
    in_deps=false
    continue
  fi

  if $in_task; then
    if [[ "$line" =~ ^[[:space:]]+category:[[:space:]]*(.*) ]]; then
      current_category=$(echo "${BASH_REMATCH[1]}" | xargs | tr -d '"')
    elif [[ "$line" =~ ^[[:space:]]+title:[[:space:]]*(.*) ]]; then
      current_title=$(echo "${BASH_REMATCH[1]}" | xargs | tr -d '"')
    elif [[ "$line" =~ ^[[:space:]]+description:[[:space:]]*(.*) ]]; then
      current_desc=$(echo "${BASH_REMATCH[1]}" | xargs | tr -d '"')
    elif [[ "$line" =~ ^[[:space:]]+complexity:[[:space:]]*(.*) ]]; then
      current_complexity=$(echo "${BASH_REMATCH[1]}" | xargs | tr -d '"')
    elif [[ "$line" =~ ^[[:space:]]+dependencies: ]]; then
      in_deps=true
    elif $in_deps && [[ "$line" =~ ^[[:space:]]+-[[:space:]]*(.*) ]]; then
      dep=$(echo "${BASH_REMATCH[1]}" | xargs | tr -d '"')
      current_deps="${current_deps}${dep},"
    elif $in_deps && [[ ! "$line" =~ ^[[:space:]]+- ]]; then
      in_deps=false
    fi
  fi
done < "$TASKS_FILE"

# Save last task
if [[ -n "$current_task_id" ]]; then
  entry="${current_task_id}|${current_title}|${current_desc}|${current_complexity}|${current_deps}"
  cat="${current_category:-implementation}"
  phase_tasks["$cat"]="${phase_tasks["$cat"]:-}${entry}"$'\n'
  task_count=$((task_count + 1))
fi

log_info "  Parsed tasks: $task_count"

# --- Generate dispatch manifest ---
OUTPUT_DIR="${OUTPUT_DIR:-.rally/dispatch}"
mkdir -p "$OUTPUT_DIR"
dispatch_manifest="${OUTPUT_DIR}/dispatch-manifest.yaml"
dispatch_at=$(timestamp)

phase_index=0
prev_phase_id=""

{
  echo "schema_version: 1"
  echo "dispatch_id: \"$(generate_id "dispatch")\""
  echo "dispatched_at: \"$dispatch_at\""
  echo "project_name: \"$dispatch_project_name\""
  echo "build_card: \"$BUILD_CARD\""
  echo "tasks_file: \"$TASKS_FILE\""
  echo "total_tasks: $task_count"
  echo ""
  echo "# Convoy phases with their beads"
  echo "convoys:"

  for phase_entry in "${CONVOY_PHASES[@]}"; do
    phase_key="${phase_entry%%:*}"
    phase_label="${phase_entry##*:}"

    # Check if this phase has any tasks
    tasks_for_phase="${phase_tasks["$phase_key"]:-}"
    [[ -z "$tasks_for_phase" ]] && continue

    convoy_id=$(generate_id "convoy")

    echo ""
    echo "  - convoy_id: \"$convoy_id\""
    echo "    phase: \"$phase_key\""
    echo "    label: \"$phase_label\""
    echo "    order: $phase_index"
    if [[ -n "$prev_phase_id" ]]; then
      echo "    depends_on: \"$prev_phase_id\""
    else
      echo "    depends_on: null"
    fi
    echo "    beads:"

    # Emit each task as a bead
    while IFS= read -r task_line; do
      [[ -z "$task_line" ]] && continue
      IFS='|' read -r tid ttitle tdesc tcomplexity tdeps <<< "$task_line"

      echo "      - task_id: \"$tid\""
      echo "        title: \"$ttitle\""
      echo "        description: \"$tdesc\""
      echo "        complexity: ${tcomplexity:-2}"
      if [[ -n "$tdeps" ]] && [[ "$tdeps" != "," ]]; then
        echo "        dependencies:"
        IFS=',' read -ra dep_arr <<< "$tdeps"
        for dep in "${dep_arr[@]}"; do
          [[ -z "$dep" ]] && continue
          echo "          - \"$dep\""
        done
      else
        echo "        dependencies: []"
      fi
    done <<< "$tasks_for_phase"

    prev_phase_id="$convoy_id"
    phase_index=$((phase_index + 1))
  done

} > "$dispatch_manifest"

# --- Dry run vs actual dispatch ---

if $DRY_RUN; then
  log_success "Dry run complete. Dispatch manifest: $dispatch_manifest"
  log_info "  Convoy phases: $phase_index"
  log_info "  Total beads: $task_count"
  log_info "  Review the manifest, then run without --dry-run to create beads."
else
  # Attempt to create beads via bd if available
  if command -v bd >/dev/null 2>&1; then
    beads_created=0
    log_info "Creating beads..."

    while IFS= read -r task_line; do
      [[ -z "$task_line" ]] && continue
      IFS='|' read -r tid ttitle tdesc tcomplexity tdeps <<< "$task_line"
      [[ -z "$ttitle" ]] && continue

      set +e
      bd create --title "$ttitle" --type task 2>/dev/null
      bd_exit=$?
      set -e

      if [[ $bd_exit -eq 0 ]]; then
        beads_created=$((beads_created + 1))
      else
        log_warn "Failed to create bead for: $ttitle"
      fi
    done < <(for key in "${!phase_tasks[@]}"; do echo "${phase_tasks[$key]}"; done)

    log_success "Dispatch complete: $beads_created beads created"
  else
    log_warn "bd command not available. Dispatch manifest generated but beads not created."
    log_info "Review: $dispatch_manifest"
  fi

  log_success "Dispatch manifest: $dispatch_manifest"
fi

log_info "  Convoy phases: $phase_index"
log_info "  Total tasks: $task_count"

echo "$dispatch_manifest"
