#!/bin/bash
# Rally Init - Create project-profile.yaml interactively
# Usage: rally init [output-path]
#   output-path: Where to write project-profile.yaml (default: ./project-profile.yaml)

source "$(dirname "$0")/../lib/common.sh"

OUTPUT="${1:-./project-profile.yaml}"
TEMPLATE="$TAVERN_ROOT/templates/project-profile.yaml"
FACETS="$TAVERN_ROOT/defaults/facets.yaml"

require_file "$TEMPLATE"
require_file "$FACETS"

if [[ -f "$OUTPUT" ]]; then
  log_warn "File already exists: $OUTPUT"
  read -rp "Overwrite? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Aborted."
    exit 0
  fi
fi

# --- Helper: read facet values from facets.yaml ---
read_facet_values() {
  local key="$1"
  local in_section=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^${key}: ]]; then
      in_section=true
      continue
    fi
    if $in_section; then
      if [[ "$line" =~ ^[a-z_]+: ]] || [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
        break
      fi
      if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.*) ]]; then
        echo "${BASH_REMATCH[1]}"
      fi
    fi
  done < "$FACETS"
}

# --- Helper: select from list ---
select_from() {
  local prompt="$1"
  shift
  local options=("$@")
  local count=${#options[@]}

  echo ""
  echo "$prompt"
  for i in "${!options[@]}"; do
    printf "  %2d) %s\n" "$((i + 1))" "${options[$i]}"
  done
  echo ""

  while true; do
    read -rp "Choice [1-$count]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
      SELECTED="${options[$((choice - 1))]}"
      return 0
    fi
    echo "  Invalid choice. Enter 1-$count."
  done
}

# --- Helper: yes/no prompt ---
ask_bool() {
  local prompt="$1"
  local default="${2:-false}"
  local hint="y/N"
  [[ "$default" == "true" ]] && hint="Y/n"

  read -rp "$prompt [$hint]: " answer
  case "$answer" in
    y|Y|yes) echo "true" ;;
    n|N|no) echo "false" ;;
    "") echo "$default" ;;
    *) echo "$default" ;;
  esac
}

# --- Helper: read multi-select (comma-separated) ---
select_multi() {
  local prompt="$1"
  shift
  local options=("$@")
  local count=${#options[@]}

  echo ""
  echo "$prompt (comma-separated, or 'none')"
  for i in "${!options[@]}"; do
    printf "  %2d) %s\n" "$((i + 1))" "${options[$i]}"
  done
  echo ""

  read -rp "Choices: " choices
  if [[ "$choices" == "none" || -z "$choices" ]]; then
    MULTI_SELECTED=()
    return
  fi

  MULTI_SELECTED=()
  IFS=',' read -ra parts <<< "$choices"
  for part in "${parts[@]}"; do
    part=$(echo "$part" | xargs)  # trim
    if [[ "$part" =~ ^[0-9]+$ ]] && (( part >= 1 && part <= count )); then
      MULTI_SELECTED+=("${options[$((part - 1))]}")
    fi
  done
}

# --- Helper: read with default ---
read_default() {
  local prompt="$1"
  local default="$2"
  local hint=""
  [[ -n "$default" ]] && hint=" [$default]"
  read -rp "${prompt}${hint}: " value
  echo "${value:-$default}"
}

# === Collect Input ===

echo ""
echo "========================================="
echo "  Rally Project Profile Initialization"
echo "========================================="
echo ""
echo "This creates a project-profile.yaml that"
echo "Rally skills use for planning and analysis."
echo ""

# --- Project Identity ---
log_info "Project Identity"
proj_name=$(read_default "Project name" "")
proj_slug=$(echo "$proj_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
proj_slug=$(read_default "Project slug" "$proj_slug")
proj_desc=$(read_default "One-line description" "")
proj_repo=$(read_default "Git repo URL (optional)" "")

# --- Platform ---
log_info "Platform & Stack"
mapfile -t platforms < <(read_facet_values "platform")
select_from "Select primary platform:" "${platforms[@]}"
proj_platform="$SELECTED"

# --- Language ---
mapfile -t languages < <(read_facet_values "language")
select_from "Select primary language:" "${languages[@]}"
proj_language="$SELECTED"

# --- Framework ---
mapfile -t frameworks < <(read_facet_values "framework")
select_from "Select framework (pick closest or 1 for none):" "none" "${frameworks[@]}"
proj_framework="$SELECTED"
[[ "$proj_framework" == "none" ]] && proj_framework=""

# --- Stack Preset ---
proj_stack_preset=""
if ls "$TAVERN_ROOT/defaults/stacks/"*.yaml >/dev/null 2>&1; then
  mapfile -t stacks < <(ls "$TAVERN_ROOT/defaults/stacks/"*.yaml 2>/dev/null | xargs -I{} basename {} .yaml)
  if (( ${#stacks[@]} > 0 )); then
    select_from "Apply a stack preset? (or 1 for none):" "none" "${stacks[@]}"
    proj_stack_preset="$SELECTED"
    [[ "$proj_stack_preset" == "none" ]] && proj_stack_preset=""
  fi
fi

# --- Facets ---
log_info "Project Facets"

mapfile -t auth_opts < <(read_facet_values "auth")
select_from "Authentication method:" "${auth_opts[@]}"
facet_auth="$SELECTED"

mapfile -t db_opts < <(read_facet_values "database")
select_from "Database:" "${db_opts[@]}"
facet_db="$SELECTED"

mapfile -t api_opts < <(read_facet_values "api_style")
select_from "API style:" "${api_opts[@]}"
facet_api="$SELECTED"

mapfile -t deploy_opts < <(read_facet_values "deployment")
select_from "Deployment target:" "${deploy_opts[@]}"
facet_deploy="$SELECTED"

mapfile -t ui_opts < <(read_facet_values "ui")
select_from "UI type:" "${ui_opts[@]}"
facet_ui="$SELECTED"

facet_realtime=$(ask_bool "Real-time features (websocket, SSE)?" "false")
facet_multitenant=$(ask_bool "Multi-tenant architecture?" "false")
facet_filestorage=$(ask_bool "File upload/storage?" "false")
facet_search=$(ask_bool "Full-text search?" "false")
facet_queue=$(ask_bool "Background jobs / message queue?" "false")
facet_caching=$(ask_bool "Caching layer?" "false")
facet_i18n=$(ask_bool "Internationalization (i18n)?" "false")

# --- Constraints ---
log_info "Constraints"

mapfile -t budget_opts < <(read_facet_values "budget")
select_from "Budget level:" "${budget_opts[@]}"
constraint_budget="$SELECTED"

mapfile -t timeline_opts < <(read_facet_values "timeline")
select_from "Timeline:" "${timeline_opts[@]}"
constraint_timeline="$SELECTED"

mapfile -t team_opts < <(read_facet_values "team_size")
select_from "Team size:" "${team_opts[@]}"
constraint_team="$SELECTED"

mapfile -t compliance_opts < <(read_facet_values "compliance")
select_multi "Compliance requirements:" "${compliance_opts[@]}"
constraint_compliance=("${MULTI_SELECTED[@]}")

mapfile -t hosting_opts < <(read_facet_values "hosting")
select_from "Hosting model:" "${hosting_opts[@]}"
constraint_hosting="$SELECTED"

# --- Priorities ---
log_info "Priorities (1=highest, 5=lowest)"
prio_speed=$(read_default "Speed to market" "3")
prio_scale=$(read_default "Scalability" "3")
prio_security=$(read_default "Security" "3")
prio_maintain=$(read_default "Maintainability" "3")
prio_dx=$(read_default "Developer experience" "3")

# --- Notes ---
proj_notes=$(read_default "Additional notes (optional)" "")

# === Generate YAML ===

# Build compliance array
compliance_yaml=""
if (( ${#constraint_compliance[@]} == 0 )); then
  compliance_yaml="[]"
else
  compliance_yaml=""
  for c in "${constraint_compliance[@]}"; do
    compliance_yaml="${compliance_yaml}
    - $c"
  done
fi

cat > "$OUTPUT" << YAML
# Rally Project Profile
# Generated by: rally init
# Created: $(timestamp)

schema_version: 1

project:
  name: "$proj_name"
  slug: "$proj_slug"
  description: "$proj_desc"
  repo: "$proj_repo"

platform: "$proj_platform"
language: "$proj_language"
framework: "$proj_framework"
stack_preset: "$proj_stack_preset"

facets:
  auth: "$facet_auth"
  database: "$facet_db"
  api_style: "$facet_api"
  deployment: "$facet_deploy"
  ui: "$facet_ui"
  realtime: $facet_realtime
  multi_tenant: $facet_multitenant
  file_storage: $facet_filestorage
  search: $facet_search
  queue: $facet_queue
  caching: $facet_caching
  i18n: $facet_i18n

constraints:
  budget: "$constraint_budget"
  timeline: "$constraint_timeline"
  team_size: "$constraint_team"
  compliance: $(if (( ${#constraint_compliance[@]} == 0 )); then echo "[]"; else echo ""; for c in "${constraint_compliance[@]}"; do echo "    - $c"; done; fi)
  hosting: "$constraint_hosting"

priorities:
  speed_to_market: $prio_speed
  scalability: $prio_scale
  security: $prio_security
  maintainability: $prio_maintain
  developer_experience: $prio_dx

notes: "$proj_notes"
YAML

echo ""
log_success "Project profile created: $OUTPUT"
log_info "Next: rally plan $OUTPUT"
