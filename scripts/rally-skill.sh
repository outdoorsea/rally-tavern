#!/bin/bash
# Rally Skill Runner — Load, execute, and validate skills
#
# Usage:
#   rally-skill.sh run <skill-name> --profile <path> [--context <dir>] [--output <path>]
#   rally-skill.sh list
#   rally-skill.sh show <skill-name>
#   rally-skill.sh validate <skill-file>

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

SKILLS_DIR="$TAVERN_ROOT/skills"
TEMPLATE="$TAVERN_ROOT/templates/skill.yaml"

ACTION="${1:-}"
shift 2>/dev/null || true

# --- Helpers ---

# Extract a simple YAML value from a skill file (flat key: value)
skill_get() {
  local file="$1" key="$2"
  grep "^${key}:" "$file" 2>/dev/null | head -1 | cut -d: -f2- | xargs
}

# Extract a YAML list under a key (returns items without leading "- ")
skill_get_list() {
  local file="$1" key="$2"
  local in_section=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^${key}: ]]; then
      in_section=true
      continue
    fi
    if $in_section; then
      # Stop at next top-level key or end of list
      if [[ "$line" =~ ^[a-z_] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
        break
      fi
      if [[ "$line" =~ ^[[:space:]]+- ]]; then
        echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//'
      fi
    fi
  done < "$file"
}

# Extract a multi-line YAML block (e.g., prompt.system)
skill_get_block() {
  local file="$1" parent="$2" child="$3"
  local in_parent=false in_child=false indent=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^${parent}: ]]; then
      in_parent=true
      continue
    fi
    if $in_parent && [[ "$line" =~ ^[[:space:]]+${child}:[[:space:]]*\| ]]; then
      in_child=true
      continue
    fi
    if $in_child; then
      # Stop at next sibling key or parent-level key
      if [[ "$line" =~ ^[a-z_] ]]; then
        break
      fi
      if [[ "$line" =~ ^[[:space:]]+[a-z_]+: ]] && [[ ! "$line" =~ ^[[:space:]]{4,} ]]; then
        break
      fi
      # Output the line with leading whitespace stripped (first 4 chars)
      echo "${line#    }"
    fi
  done < "$file"
}

# Resolve skill file path from name
resolve_skill() {
  local name="$1"
  local skill_file="$SKILLS_DIR/${name}.yaml"
  if [[ ! -f "$skill_file" ]]; then
    log_error "Skill not found: $name"
    log_info "Available skills:"
    rally_skill_list_names
    exit 1
  fi
  echo "$skill_file"
}

# List skill names (just filenames)
rally_skill_list_names() {
  for f in "$SKILLS_DIR"/*.yaml; do
    [[ -f "$f" ]] || continue
    basename "$f" .yaml
  done
}

# Validate a skill definition file has required fields
validate_skill_file() {
  local skill_file="$1"
  local errors=0

  local name version description
  name=$(skill_get "$skill_file" "name")
  version=$(skill_get "$skill_file" "version")
  description=$(skill_get "$skill_file" "description")

  if [[ -z "$name" ]]; then
    log_error "Skill missing 'name'"
    errors=$((errors + 1))
  fi
  if [[ -z "$version" ]]; then
    log_error "Skill missing 'version'"
    errors=$((errors + 1))
  fi
  if [[ -z "$description" ]]; then
    log_error "Skill missing 'description'"
    errors=$((errors + 1))
  fi

  # Check for prompt section
  if ! grep -q "^prompt:" "$skill_file"; then
    log_error "Skill missing 'prompt' section"
    errors=$((errors + 1))
  fi

  # Check for output section
  if ! grep -q "^output:" "$skill_file"; then
    log_error "Skill missing 'output' section"
    errors=$((errors + 1))
  fi

  # Check for required_keys
  local required_keys
  required_keys=$(skill_get_list "$skill_file" "  required_keys" 2>/dev/null || true)
  if [[ -z "$required_keys" ]]; then
    log_warn "Skill has no output.required_keys — output won't be validated"
  fi

  return $errors
}

# Validate skill output YAML has required keys
validate_output() {
  local output_file="$1" skill_file="$2"
  local errors=0

  # Get required keys from the skill's output section
  # Parse under output.required_keys
  local in_output=false in_keys=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^output: ]]; then
      in_output=true
      continue
    fi
    if $in_output && [[ "$line" =~ ^[[:space:]]+required_keys: ]]; then
      in_keys=true
      continue
    fi
    if $in_keys; then
      # Stop at next top-level key
      if [[ "$line" =~ ^[a-z_] ]]; then
        break
      fi
      # Stop at next sibling key (indented key that's not a list item)
      if [[ "$line" =~ ^[[:space:]]+[a-z_]+: ]] && [[ ! "$line" =~ ^[[:space:]]+- ]]; then
        break
      fi
      if [[ "$line" =~ ^[[:space:]]+- ]]; then
        local key
        key=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')
        if ! grep -q "^${key}:" "$output_file" 2>/dev/null; then
          log_error "Output missing required key: $key"
          errors=$((errors + 1))
        fi
      fi
    fi
  done < "$skill_file"

  return $errors
}

# --- Commands ---

rally_skill_list() {
  echo "📋 Available Skills"
  echo ""

  local count=0
  for f in "$SKILLS_DIR"/*.yaml; do
    [[ -f "$f" ]] || continue
    local name desc version
    name=$(skill_get "$f" "name")
    desc=$(skill_get "$f" "description")
    version=$(skill_get "$f" "version")
    echo "  $name (v${version:-1})"
    echo "    $desc"
    echo ""
    count=$((count + 1))
  done

  if [[ $count -eq 0 ]]; then
    echo "  (no skills installed)"
    echo ""
    echo "  Place skill YAML files in: $SKILLS_DIR/"
    echo "  See template: templates/skill.yaml"
  fi
}

rally_skill_show() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    log_error "Usage: rally skill show <skill-name>"
    exit 1
  fi
  local skill_file
  skill_file=$(resolve_skill "$name")
  cat "$skill_file"
}

rally_skill_validate() {
  local path="${1:-}"
  if [[ -z "$path" ]]; then
    log_error "Usage: rally skill validate <skill-file>"
    exit 1
  fi
  require_file "$path"

  if validate_skill_file "$path"; then
    log_success "Skill definition is valid: $(skill_get "$path" "name")"
  else
    log_error "Skill definition has errors"
    exit 1
  fi
}

rally_skill_run() {
  local skill_name="" profile_path="" context_dir="" output_path=""

  # Parse arguments
  skill_name="${1:-}"
  shift 2>/dev/null || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        profile_path="${2:-}"
        shift 2
        ;;
      --context)
        context_dir="${2:-}"
        shift 2
        ;;
      --output)
        output_path="${2:-}"
        shift 2
        ;;
      *)
        log_error "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  # Validate inputs
  if [[ -z "$skill_name" ]]; then
    log_error "Usage: rally skill run <skill-name> --profile <path> [--context <dir>] [--output <path>]"
    exit 1
  fi
  if [[ -z "$profile_path" ]]; then
    log_error "Missing required --profile argument"
    exit 1
  fi
  require_file "$profile_path"

  local skill_file
  skill_file=$(resolve_skill "$skill_name")

  # Validate skill definition
  if ! validate_skill_file "$skill_file"; then
    log_error "Invalid skill definition"
    exit 1
  fi

  # Set up output path
  if [[ -z "$output_path" ]]; then
    local build_dir="/tmp/rally-build"
    mkdir -p "$build_dir"
    output_path="${build_dir}/${skill_name}.yaml"
  fi

  local name desc
  name=$(skill_get "$skill_file" "name")
  desc=$(skill_get "$skill_file" "description")
  log_info "Running skill: $name"
  log_info "  Description: $desc"
  log_info "  Profile: $profile_path"
  if [[ -n "$context_dir" ]]; then
    log_info "  Context: $context_dir"
  fi
  log_info "  Output: $output_path"

  # Build the system prompt
  local system_prompt
  system_prompt=$(skill_get_block "$skill_file" "prompt" "system")

  # Build the user prompt with template substitution
  local user_prompt
  user_prompt=$(skill_get_block "$skill_file" "prompt" "user")

  # Read profile contents
  local profile_contents
  profile_contents=$(cat "$profile_path")

  # Substitute {{project-profile}} in user prompt
  user_prompt="${user_prompt//\{\{project-profile\}\}/$profile_contents}"

  # If context dir provided, gather context files
  if [[ -n "$context_dir" ]] && [[ -d "$context_dir" ]]; then
    local context_contents=""
    for ctx_file in "$context_dir"/*.yaml; do
      [[ -f "$ctx_file" ]] || continue
      context_contents="${context_contents}--- $(basename "$ctx_file") ---
$(cat "$ctx_file")

"
    done
    user_prompt="${user_prompt//\{\{context\}\}/$context_contents}"
  else
    user_prompt="${user_prompt//\{\{context\}\}/}"
  fi

  # Invoke Claude CLI
  log_info "Invoking Claude..."

  local claude_output
  if ! claude_output=$(echo "$user_prompt" | claude --print --system-prompt "$system_prompt" 2>/dev/null); then
    log_error "Claude invocation failed"
    exit 1
  fi

  # Extract YAML from Claude output (strip markdown fences if present)
  local yaml_output
  yaml_output=$(echo "$claude_output" | sed -n '/^```yaml/,/^```$/p' | sed '1d;$d')
  if [[ -z "$yaml_output" ]]; then
    # Try without fences — maybe Claude returned raw YAML
    yaml_output="$claude_output"
  fi

  # Write output
  mkdir -p "$(dirname "$output_path")"
  echo "$yaml_output" > "$output_path"

  # Validate output has required keys
  local validation_ok=true
  if ! validate_output "$output_path" "$skill_file"; then
    log_warn "Output validation failed — some required keys missing"
    validation_ok=false
  fi

  if $validation_ok; then
    log_success "Skill output saved: $output_path"
  else
    log_warn "Skill output saved with warnings: $output_path"
  fi

  echo "$output_path"
}

# --- Dispatch ---

case "$ACTION" in
  run)
    rally_skill_run "$@"
    ;;
  list)
    rally_skill_list
    ;;
  show)
    rally_skill_show "$@"
    ;;
  validate)
    rally_skill_validate "$@"
    ;;
  *)
    echo "Rally Skill Runner"
    echo ""
    echo "Usage: rally skill <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  run <name> --profile <path>    Execute a skill"
    echo "  list                           List available skills"
    echo "  show <name>                    Show skill definition"
    echo "  validate <file>                Validate skill YAML"
    echo ""
    echo "Options for run:"
    echo "  --profile <path>    Project profile (required)"
    echo "  --context <dir>     Pipeline context directory"
    echo "  --output <path>     Output file path"
    echo ""
    echo "Skills directory: $SKILLS_DIR/"
    exit 1
    ;;
esac
