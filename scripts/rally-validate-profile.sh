#!/bin/bash
# Rally Validate Profile - Validate project-profile.yaml
# Usage: rally-validate-profile.sh <profile-path>
#
# Validates:
#   - Required fields present and non-empty
#   - Facet values match vocabulary in defaults/facets.yaml
#   - Priority values are 1-5
#   - Schema version is supported

source "$(dirname "$0")/../lib/common.sh"

PROFILE="${1:-}"
FACETS="$TAVERN_ROOT/defaults/facets.yaml"

if [[ -z "$PROFILE" ]]; then
  log_error "Usage: rally-validate-profile.sh <profile-path>"
  exit 1
fi

require_file "$PROFILE"
require_file "$FACETS"

ERRORS=0
WARNINGS=0

# --- Helpers ---

check_required() {
  local key="$1"
  local label="${2:-$key}"
  local value
  value=$(yaml_get "$PROFILE" "$key") || true
  if [[ -z "$value" ]]; then
    log_error "Missing required field: $label"
    ERRORS=$((ERRORS + 1))
  fi
}

check_nested_required() {
  local section="$1"
  local key="$2"
  local label="${3:-$section.$key}"
  local value
  value=$(grep -A 50 "^${section}:" "$PROFILE" | grep "^  ${key}:" | head -1 | cut -d: -f2- | xargs) || true
  if [[ -z "$value" || "$value" == '""' ]]; then
    log_error "Missing required field: $label"
    ERRORS=$((ERRORS + 1))
  fi
}

get_nested() {
  local section="$1"
  local key="$2"
  grep -A 50 "^${section}:" "$PROFILE" 2>/dev/null | grep "^  ${key}:" 2>/dev/null | head -1 | cut -d: -f2- | xargs 2>/dev/null || true
}

# Check if value is in facets vocabulary
check_facet() {
  local facet_key="$1"
  local value="$2"
  local label="${3:-$facet_key}"

  if [[ -z "$value" || "$value" == "none" || "$value" == '""' ]]; then
    return 0  # Empty/none is valid for optional facets
  fi

  # Read valid values from facets.yaml
  local valid=false
  local in_section=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^${facet_key}: ]]; then
      in_section=true
      continue
    fi
    if $in_section; then
      if [[ "$line" =~ ^[a-z_]+: ]] || [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
        break
      fi
      if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.*) ]]; then
        local candidate="${BASH_REMATCH[1]}"
        if [[ "$candidate" == "$value" ]]; then
          valid=true
          break
        fi
      fi
    fi
  done < "$FACETS"

  if ! $valid; then
    log_warn "Unknown $label value: '$value' (not in facets vocabulary)"
    WARNINGS=$((WARNINGS + 1))
  fi
}

check_priority() {
  local key="$1"
  local value
  value=$(get_nested "priorities" "$key")
  if [[ -n "$value" ]]; then
    if ! [[ "$value" =~ ^[1-5]$ ]]; then
      log_error "Priority $key must be 1-5, got: '$value'"
      ERRORS=$((ERRORS + 1))
    fi
  fi
}

check_bool() {
  local section="$1"
  local key="$2"
  local value
  value=$(get_nested "$section" "$key")
  if [[ -n "$value" && "$value" != "true" && "$value" != "false" ]]; then
    log_error "$section.$key must be true or false, got: '$value'"
    ERRORS=$((ERRORS + 1))
  fi
}

# === Validation ===

log_info "Validating: $PROFILE"
echo ""

# Schema version
schema_ver=$(yaml_get "$PROFILE" "schema_version") || true
if [[ "$schema_ver" != "1" ]]; then
  log_error "Unsupported schema_version: '$schema_ver' (expected: 1)"
  ERRORS=$((ERRORS + 1))
fi

# Project identity (required)
check_nested_required "project" "name" "project.name"
check_nested_required "project" "slug" "project.slug"
check_nested_required "project" "description" "project.description"

# Slug format
proj_slug=$(get_nested "project" "slug") || true
if [[ -n "$proj_slug" && ! "$proj_slug" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  log_error "project.slug must be lowercase alphanumeric with hyphens: '$proj_slug'"
  ERRORS=$((ERRORS + 1))
fi

# Platform & language (required)
platform=$(yaml_get "$PROFILE" "platform") || true
language=$(yaml_get "$PROFILE" "language") || true

if [[ -z "$platform" || "$platform" == '""' ]]; then
  log_error "Missing required field: platform"
  ERRORS=$((ERRORS + 1))
else
  check_facet "platform" "$platform" "platform"
fi

if [[ -z "$language" || "$language" == '""' ]]; then
  log_error "Missing required field: language"
  ERRORS=$((ERRORS + 1))
else
  check_facet "language" "$language" "language"
fi

# Framework (optional but validate if present)
framework=$(yaml_get "$PROFILE" "framework") || true
if [[ -n "$framework" && "$framework" != '""' ]]; then
  check_facet "framework" "$framework" "framework"
fi

# Facet values
facet_auth=$(get_nested "facets" "auth")
facet_db=$(get_nested "facets" "database")
facet_api=$(get_nested "facets" "api_style")
facet_deploy=$(get_nested "facets" "deployment")
facet_ui=$(get_nested "facets" "ui")

check_facet "auth" "$facet_auth" "facets.auth"
check_facet "database" "$facet_db" "facets.database"
check_facet "api_style" "$facet_api" "facets.api_style"
check_facet "deployment" "$facet_deploy" "facets.deployment"
check_facet "ui" "$facet_ui" "facets.ui"

# Boolean facets
for bool_facet in realtime multi_tenant file_storage search queue caching i18n; do
  check_bool "facets" "$bool_facet"
done

# Constraints
constraint_budget=$(get_nested "constraints" "budget")
constraint_timeline=$(get_nested "constraints" "timeline")
constraint_team=$(get_nested "constraints" "team_size")
constraint_hosting=$(get_nested "constraints" "hosting")

[[ -n "$constraint_budget" ]] && check_facet "budget" "$constraint_budget" "constraints.budget"
[[ -n "$constraint_timeline" ]] && check_facet "timeline" "$constraint_timeline" "constraints.timeline"
[[ -n "$constraint_team" ]] && check_facet "team_size" "$constraint_team" "constraints.team_size"
[[ -n "$constraint_hosting" ]] && check_facet "hosting" "$constraint_hosting" "constraints.hosting"

# Priorities
for prio in speed_to_market scalability security maintainability developer_experience; do
  check_priority "$prio"
done

# === Results ===

echo ""
if (( ERRORS > 0 )); then
  log_error "Validation failed: $ERRORS error(s), $WARNINGS warning(s)"
  exit 1
elif (( WARNINGS > 0 )); then
  log_warn "Validation passed with $WARNINGS warning(s)"
  exit 0
else
  log_success "Validation passed: profile is valid"
  exit 0
fi
