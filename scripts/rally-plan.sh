#!/bin/bash
# Rally Plan — Build Card Generation (Feature 10)
# Orchestrates skill pipeline to produce a unified build-card.yaml
#
# Usage:
#   rally-plan.sh <project-profile.yaml> [--output <path>] [--build-dir <dir>]
#
# Pipeline: product-manager → oss-researcher → architect → security-auditor
# Missing or failing skills are recorded, not fatal.

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

SKILL_RUNNER="${RALLY_SKILL_RUNNER:-$TAVERN_ROOT/scripts/rally-skill.sh}"

# Default pipeline order — skill name and build card section
PIPELINE_SKILLS=(
  "product-manager:product"
  "oss-researcher:oss_analysis"
  "architect:architecture"
  "security-auditor:security_review"
)

# --- Argument parsing ---

PROFILE_PATH=""
OUTPUT_PATH=""
BUILD_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    --build-dir)
      BUILD_DIR="${2:-}"
      shift 2
      ;;
    --help|-h)
      echo "Rally Plan — Build Card Generation"
      echo ""
      echo "Usage: rally plan <project-profile.yaml> [options]"
      echo ""
      echo "Options:"
      echo "  --output <path>      Output build card path (default: ./build-card.yaml)"
      echo "  --build-dir <dir>    Working directory for intermediates (default: /tmp/rally-build)"
      echo ""
      echo "Pipeline: product-manager → oss-researcher → architect → security-auditor"
      echo "Missing skills are recorded as not_available, not treated as errors."
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      exit 1
      ;;
    *)
      if [[ -z "$PROFILE_PATH" ]]; then
        PROFILE_PATH="$1"
      else
        log_error "Unexpected argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$PROFILE_PATH" ]]; then
  log_error "Usage: rally plan <project-profile.yaml> [--output <path>]"
  exit 1
fi

require_file "$PROFILE_PATH"

# Defaults
BUILD_DIR="${BUILD_DIR:-/tmp/rally-build}"
OUTPUT_PATH="${OUTPUT_PATH:-./build-card.yaml}"

# --- Setup ---

mkdir -p "$BUILD_DIR"
log_info "Build Card Generation"
log_info "  Profile: $PROFILE_PATH"
log_info "  Build dir: $BUILD_DIR"
log_info "  Output: $OUTPUT_PATH"

# Extract project name from profile
PROJECT_NAME=$(yaml_get "$PROFILE_PATH" "  name" 2>/dev/null || echo "unknown")

# --- Run pipeline ---

completed_sections=()
missing_sections=()
failed_sections=()
skill_outputs=()
step_index=0

for entry in "${PIPELINE_SKILLS[@]}"; do
  skill_name="${entry%%:*}"
  section_name="${entry##*:}"

  log_info "Running skill: $skill_name → $section_name"

  # Check if skill exists
  skill_file="$TAVERN_ROOT/skills/${skill_name}.yaml"
  if [[ ! -f "$skill_file" ]]; then
    log_warn "Skill not found: $skill_name — marking $section_name as not_available"
    missing_sections+=("$section_name")
    step_index=$((step_index + 1))
    continue
  fi

  # Determine output file with ordering prefix
  output_file="${BUILD_DIR}/$(printf '%02d' "$step_index")-${skill_name}.yaml"

  # Run the skill
  set +e
  skill_result=$("$SKILL_RUNNER" run "$skill_name" \
    --profile "$PROFILE_PATH" \
    --context "$BUILD_DIR" \
    --output "$output_file" 2>&1)
  skill_exit=$?
  set -e

  if [[ $skill_exit -ne 0 ]]; then
    log_warn "Skill failed: $skill_name (exit $skill_exit) — marking $section_name as not_available"
    log_warn "  Output: $skill_result"
    failed_sections+=("$section_name")
    step_index=$((step_index + 1))
    continue
  fi

  if [[ ! -f "$output_file" ]]; then
    log_warn "Skill produced no output: $skill_name — marking $section_name as not_available"
    failed_sections+=("$section_name")
    step_index=$((step_index + 1))
    continue
  fi

  log_success "Skill complete: $skill_name → $output_file"
  completed_sections+=("$section_name")
  skill_outputs+=("$section_name:$output_file")
  step_index=$((step_index + 1))
done

# --- Determine status ---

total_skills=${#PIPELINE_SKILLS[@]}
completed_count=${#completed_sections[@]}

if [[ $completed_count -eq $total_skills ]]; then
  build_status="complete"
elif [[ $completed_count -eq 0 ]]; then
  build_status="failed"
else
  build_status="partial"
fi

# --- Assemble build card ---

log_info "Assembling build card (status: $build_status)"

GENERATED_AT=$(timestamp)

# Collect all missing/failed section names
all_missing=()
for s in "${missing_sections[@]+"${missing_sections[@]}"}"; do
  [[ -n "$s" ]] && all_missing+=("$s")
done
for s in "${failed_sections[@]+"${failed_sections[@]}"}"; do
  [[ -n "$s" ]] && all_missing+=("$s")
done

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_PATH")"

# Build the YAML output
{
  echo "schema_version: 1"
  echo "generated_at: \"$GENERATED_AT\""
  echo "project_name: \"$PROJECT_NAME\""
  echo "status: $build_status"
  echo ""

  # Missing sections list
  echo "missing_sections:"
  if [[ ${#all_missing[@]} -eq 0 ]]; then
    echo "  []"
  else
    for section in "${all_missing[@]}"; do
      echo "  - $section"
    done
  fi
  echo ""

  # Completed sections list
  echo "completed_sections:"
  if [[ ${#completed_sections[@]} -eq 0 ]]; then
    echo "  []"
  else
    for section in "${completed_sections[@]}"; do
      echo "  - $section"
    done
  fi
  echo ""

  # Emit each completed section
  if [[ ${#skill_outputs[@]} -gt 0 ]]; then
    for entry in "${skill_outputs[@]}"; do
      section_name="${entry%%:*}"
      output_file="${entry##*:}"

      echo "# --- $section_name ---"
      echo "${section_name}:"

      # Indent the skill output under the section key
      while IFS= read -r line; do
        if [[ -n "$line" ]]; then
          echo "  $line"
        else
          echo ""
        fi
      done < "$output_file"
      echo ""
    done
  fi

  # Emit placeholders for missing/failed sections
  for section in "${missing_sections[@]+"${missing_sections[@]}"}"; do
    [[ -z "$section" ]] && continue
    echo "# --- $section ---"
    echo "${section}:"
    echo "  status: not_available"
    echo "  reason: \"skill not found\""
    echo ""
  done

  for section in "${failed_sections[@]+"${failed_sections[@]}"}"; do
    [[ -z "$section" ]] && continue
    echo "# --- $section ---"
    echo "${section}:"
    echo "  status: not_available"
    echo "  reason: \"skill execution failed\""
    echo ""
  done

} > "$OUTPUT_PATH"

# --- Summary ---

echo ""
log_success "Build card generated: $OUTPUT_PATH"
log_info "  Status: $build_status"
log_info "  Completed: ${completed_count}/${total_skills} sections"
if [[ ${#all_missing[@]} -gt 0 ]]; then
  log_warn "  Missing: ${all_missing[*]}"
fi

echo "$OUTPUT_PATH"
