#!/bin/bash
# Rally Tasks — Execution Task Generation (Feature 18)
# Generates structured tasks from a build card for dispatch to polecats.
#
# Usage:
#   rally-tasks.sh generate <build-card.yaml> [--output <path>]
#   rally-tasks.sh show <tasks.yaml>

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

ACTION="${1:-help}"
shift 2>/dev/null || true

# --- Generate ---

cmd_generate() {
  local build_card="" output=""

  # First positional arg is build card
  if [[ $# -gt 0 ]] && [[ "${1:0:1}" != "-" ]]; then
    build_card="$1"
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output) output="${2:-}"; shift 2;;
      --help|-h)
        echo "Usage: rally tasks generate <build-card.yaml> [--output <path>]"
        exit 0
        ;;
      *) log_error "Unknown option: $1"; exit 1;;
    esac
  done

  [[ -z "$build_card" ]] && { log_error "Usage: rally tasks generate <build-card.yaml> [--output <path>]"; exit 1; }
  require_file "$build_card"

  output="${output:-${build_card%.yaml}-tasks.yaml}"

  local project_name build_status generated_at
  project_name=$(yaml_get "$build_card" "project_name" 2>/dev/null || echo "unknown")
  build_status=$(yaml_get "$build_card" "status" 2>/dev/null || echo "unknown")

  log_info "Task Generation"
  log_info "  Build card: $build_card"
  log_info "  Project: $project_name"

  # --- Read completed sections from build card ---
  local completed_sections=()
  local in_completed=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^completed_sections: ]]; then
      in_completed=true
      continue
    fi
    if $in_completed; then
      if [[ "$line" =~ ^[a-z] ]]; then
        break
      fi
      if [[ "$line" =~ ^[[:space:]]+-[[:space:]]*(.*) ]]; then
        local section
        section=$(echo "${BASH_REMATCH[1]}" | xargs)
        completed_sections+=("$section")
      fi
    fi
  done < "$build_card"

  # --- Generate tasks based on available sections ---
  local task_index=0
  local tasks=()

  # Map sections to task categories and generate tasks
  for section in "${completed_sections[@]}"; do
    case "$section" in
      product)
        tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "pm" \
          "Review and validate product requirements" \
          "Review the product section of the build card. Validate problem statement, success metrics, and acceptance criteria. Identify any gaps." \
          "2" "")")
        task_index=$((task_index + 1))

        tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "pm" \
          "Define non-goals and scope boundaries" \
          "Ensure non-goals are clearly defined to prevent scope creep during implementation." \
          "1" "task-$(printf '%03d' $((task_index - 1)))")")
        task_index=$((task_index + 1))
        ;;

      oss_analysis)
        tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "implementation" \
          "Evaluate and integrate recommended OSS packages" \
          "Review OSS analysis recommendations. Evaluate top candidates, run proof-of-concept tests, and integrate selected packages." \
          "3" "")")
        task_index=$((task_index + 1))
        ;;

      architecture)
        tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "architecture" \
          "Implement core architecture scaffold" \
          "Set up the project structure following the architecture recommendations. Create directories, base classes, and dependency injection configuration." \
          "3" "")")
        task_index=$((task_index + 1))

        tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "architecture" \
          "Define abstraction boundaries and interfaces" \
          "Create interface definitions and abstraction layers as specified in the architecture review. Ensure external APIs are isolated behind adapters." \
          "3" "task-$(printf '%03d' $((task_index - 1)))")")
        task_index=$((task_index + 1))

        tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "implementation" \
          "Implement entity models and data layer" \
          "Build data models and repository layer based on architecture entity model. Set up database migrations." \
          "3" "task-$(printf '%03d' $((task_index - 1)))")")
        task_index=$((task_index + 1))
        ;;

      security_review)
        tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "security" \
          "Implement required security controls" \
          "Apply security controls identified in the security review: input validation, authentication, authorization, encryption at rest/transit." \
          "3" "")")
        task_index=$((task_index + 1))

        tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "test" \
          "Write security test cases" \
          "Create tests for each attack vector identified in the security review. Include injection tests, auth bypass tests, and boundary tests." \
          "2" "task-$(printf '%03d' $((task_index - 1)))")")
        task_index=$((task_index + 1))
        ;;

      brand|ux)
        tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "ux" \
          "Implement UI scaffold and screen layouts" \
          "Build the screen inventory from the UX review. Set up navigation, layout components, and responsive design." \
          "3" "")")
        task_index=$((task_index + 1))
        ;;

      test_strategy)
        tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "test" \
          "Set up test infrastructure" \
          "Configure test runner, create fixture factories, set up CI test pipeline. Follow test strategy coverage targets." \
          "2" "")")
        task_index=$((task_index + 1))

        tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "test" \
          "Write unit tests for core business logic" \
          "Create unit tests for all business logic modules. Target coverage specified in test strategy." \
          "3" "task-$(printf '%03d' $((task_index - 1)))")")
        task_index=$((task_index + 1))

        tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "test" \
          "Write integration tests" \
          "Create integration tests for API endpoints, database operations, and external service interactions." \
          "3" "task-$(printf '%03d' $((task_index - 1)))")")
        task_index=$((task_index + 1))
        ;;
    esac
  done

  # Always add a final integration task
  local dep_list=""
  if [[ $task_index -gt 0 ]]; then
    dep_list="task-$(printf '%03d' $((task_index - 1)))"
  fi
  tasks+=("$(format_task "task-$(printf '%03d' $task_index)" "implementation" \
    "End-to-end integration and smoke testing" \
    "Verify all components work together. Run full test suite, check for regressions, validate acceptance criteria from product section." \
    "2" "$dep_list")")
  task_index=$((task_index + 1))

  # --- Write tasks file ---
  mkdir -p "$(dirname "$output")"

  {
    echo "schema_version: 1"
    echo "generated_at: \"$(timestamp)\""
    echo "project_name: \"$project_name\""
    echo "build_card: \"$build_card\""
    echo "total_tasks: $task_index"
    echo ""
    echo "# Task categories: pm, ux, architecture, security, test, implementation"
    echo "tasks:"
    for task in "${tasks[@]}"; do
      echo "$task"
    done
  } > "$output"

  log_success "Tasks generated: $output"
  log_info "  Total tasks: $task_index"
  log_info "  From sections: ${completed_sections[*]}"

  echo "$output"
}

# --- Format task helper ---

format_task() {
  local id="$1" category="$2" title="$3" description="$4" complexity="$5" dependencies="$6"

  local result=""
  result+="  - id: \"$id\""$'\n'
  result+="    category: \"$category\""$'\n'
  result+="    title: \"$title\""$'\n'
  result+="    description: \"$description\""$'\n'
  result+="    complexity: $complexity"$'\n'
  result+="    acceptance_criteria:"$'\n'
  result+="      - \"Task completed and verified\""$'\n'
  if [[ -n "$dependencies" ]]; then
    result+="    dependencies:"$'\n'
    result+="      - \"$dependencies\""
  else
    result+="    dependencies: []"
  fi

  echo "$result"
}

# --- Show ---

cmd_show() {
  local tasks_file="${1:-}"
  [[ -z "$tasks_file" ]] && { log_error "Usage: rally tasks show <tasks.yaml>"; exit 1; }
  require_file "$tasks_file"

  local project_name total_tasks
  project_name=$(yaml_get "$tasks_file" "project_name" 2>/dev/null || echo "unknown")
  total_tasks=$(yaml_get "$tasks_file" "total_tasks" 2>/dev/null || echo "0")

  echo "📋 Task List: $project_name"
  echo "   Total tasks: $total_tasks"
  echo ""

  # Parse and display tasks
  local in_tasks=false
  local tid="" tcategory="" ttitle="" tcomplexity=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^tasks: ]]; then
      in_tasks=true
      continue
    fi
    if ! $in_tasks; then continue; fi

    if [[ "$line" =~ ^[[:space:]]{2}-[[:space:]]id:[[:space:]]*(.*) ]]; then
      # Print previous task
      if [[ -n "$tid" ]]; then
        echo "  [$tcategory] $tid: $ttitle (complexity: $tcomplexity)"
      fi
      tid=$(echo "${BASH_REMATCH[1]}" | xargs | tr -d '"')
      tcategory=""
      ttitle=""
      tcomplexity=""
    elif [[ "$line" =~ ^[[:space:]]+category:[[:space:]]*(.*) ]]; then
      tcategory=$(echo "${BASH_REMATCH[1]}" | xargs | tr -d '"')
    elif [[ "$line" =~ ^[[:space:]]+title:[[:space:]]*(.*) ]]; then
      ttitle=$(echo "${BASH_REMATCH[1]}" | xargs | tr -d '"')
    elif [[ "$line" =~ ^[[:space:]]+complexity:[[:space:]]*(.*) ]]; then
      tcomplexity=$(echo "${BASH_REMATCH[1]}" | xargs | tr -d '"')
    fi
  done < "$tasks_file"

  # Print last task
  if [[ -n "$tid" ]]; then
    echo "  [$tcategory] $tid: $ttitle (complexity: $tcomplexity)"
  fi
}

# --- Help ---

cmd_help() {
  echo "Rally Tasks — Execution Task Generation"
  echo ""
  echo "Usage: rally tasks <action> [args...]"
  echo ""
  echo "Actions:"
  echo "  generate <build-card>   Generate tasks from a build card"
  echo "  show <tasks.yaml>       Display task list"
  echo "  help                    Show this help"
  echo ""
  echo "Examples:"
  echo "  rally tasks generate build-card.yaml"
  echo "  rally tasks generate build-card.yaml --output my-tasks.yaml"
  echo "  rally tasks show build-card-tasks.yaml"
}

# --- Dispatch ---

case "$ACTION" in
  generate) cmd_generate "$@";;
  show)     cmd_show "$@";;
  help|--help|-h) cmd_help;;
  *)
    log_error "Unknown action: $ACTION"
    cmd_help
    exit 1
    ;;
esac
