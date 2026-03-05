#!/bin/bash
# Rally Component Management
# Wraps artifact lifecycle with rally-native CLI surface
#
# Usage: rally-component.sh <action> [args...]
#
# Actions:
#   validate <path>       Validate a component manifest
#   new <name> [opts]     Create a new component from template
#   add <path>            Register an existing component
#   search <query>        Search components by text
#   list [--capability C] List components, optionally filtered by capability
#   show <id>             Show component details
#   resolve <profile>     Resolve components for a project profile

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="${ARTIFACT_DIR_OVERRIDE:-$ROOT_DIR/artifacts}"
ARTIFACT_SH="$SCRIPT_DIR/artifact.sh"
SEARCH_SH="$SCRIPT_DIR/artifacts-search.sh"
RESOLVE_SH="$SCRIPT_DIR/component-resolve.sh"

source "$ROOT_DIR/lib/common.sh"

ACTION="${1:-help}"
shift 2>/dev/null || true

require_yq() {
  command -v yq >/dev/null 2>&1 || { log_error "yq is required. Install: brew install yq"; exit 1; }
}

# --- Validate ---
# Enhanced validation: checks provides, compatibility, entrypoints
cmd_validate() {
  local path="${1:-.}"
  [[ -f "$path/artifact.yaml" ]] || { log_error "No artifact.yaml in: $path"; exit 1; }

  require_yq

  local manifest="$path/artifact.yaml"
  local errors=0
  local warnings=0

  echo "Validating component: $path"
  echo ""

  # Required fields
  local name version desc
  name=$(yq -r '.name // .metadata.id // ""' "$manifest")
  version=$(yq -r '.version // .metadata.version // ""' "$manifest")
  desc=$(yq -r '.description // .metadata.description // ""' "$manifest")

  if [[ -z "$name" ]]; then
    log_error "Missing required field: name"
    errors=$((errors + 1))
  else
    # Validate naming convention (kebab-case)
    if [[ ! "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
      log_warn "Name should be lowercase kebab-case: $name"
      warnings=$((warnings + 1))
    fi
  fi

  if [[ -z "$version" ]]; then
    log_error "Missing required field: version"
    errors=$((errors + 1))
  else
    # Validate semver format
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      log_warn "Version should be semver (e.g., 0.1.0): $version"
      warnings=$((warnings + 1))
    fi
  fi

  if [[ -z "$desc" ]]; then
    log_warn "Missing recommended field: description"
    warnings=$((warnings + 1))
  fi

  # Provides (capabilities)
  local provides_count
  provides_count=$(yq -r '(.provides // []) | length' "$manifest" 2>/dev/null || echo "0")
  if [[ "$provides_count" -eq 0 ]]; then
    log_warn "No capabilities declared in 'provides' — component won't appear in capability searches"
    warnings=$((warnings + 1))
  else
    # Validate each capability has both fields
    local i=0
    while [[ $i -lt $provides_count ]]; do
      local cap style
      cap=$(yq -r ".provides[$i].capability // \"\"" "$manifest" 2>/dev/null)
      style=$(yq -r ".provides[$i].style // \"\"" "$manifest" 2>/dev/null)
      if [[ -z "$cap" ]]; then
        log_error "provides[$i] missing 'capability' field"
        errors=$((errors + 1))
      fi
      if [[ -z "$style" ]]; then
        log_warn "provides[$i] missing 'style' field"
        warnings=$((warnings + 1))
      fi
      i=$((i + 1))
    done
  fi

  # Compatibility
  local platforms_count languages_count
  platforms_count=$(yq -r '(.compatibility.platforms // .spec.compatibility.platforms // []) | length' "$manifest" 2>/dev/null || echo "0")
  languages_count=$(yq -r '(.compatibility.languages // .spec.compatibility.languages // []) | length' "$manifest" 2>/dev/null || echo "0")
  if [[ "$platforms_count" -eq 0 ]] && [[ "$languages_count" -eq 0 ]]; then
    log_warn "No compatibility constraints — component matches all platforms"
    warnings=$((warnings + 1))
  fi

  # Artifact type
  local artifact_type
  artifact_type=$(yq -r '.spec.artifactType // ""' "$manifest" 2>/dev/null)
  if [[ -z "$artifact_type" ]]; then
    log_warn "Missing spec.artifactType"
    warnings=$((warnings + 1))
  else
    case "$artifact_type" in
      starter-template|module|skill|mcp-server|playbook) ;;
      *) log_error "Invalid spec.artifactType: $artifact_type"; errors=$((errors + 1));;
    esac
  fi

  # Tags
  local tags_count
  tags_count=$(yq -r '(.tags // .metadata.tags // []) | length' "$manifest" 2>/dev/null || echo "0")
  if [[ "$tags_count" -eq 0 ]]; then
    log_warn "No tags — component won't appear in text searches"
    warnings=$((warnings + 1))
  fi

  # Trust tier
  local trust
  trust=$(yq -r '.trust_tier // .trust.level // ""' "$manifest" 2>/dev/null)
  if [[ -n "$trust" ]]; then
    case "$trust" in
      experimental|community|verified) ;;
      *) log_error "Invalid trust tier: $trust"; errors=$((errors + 1));;
    esac
  fi

  # Directory structure
  [[ -d "$path/templates" ]] || { log_warn "No templates/ directory"; warnings=$((warnings + 1)); }
  [[ -d "$path/acceptance" ]] || { log_warn "No acceptance/ directory"; warnings=$((warnings + 1)); }

  # Entrypoints
  local has_entrypoints=false
  local ep_test
  ep_test=$(yq -r '.entrypoints.test // .spec.entrypoints.test // ""' "$manifest" 2>/dev/null)
  if [[ -n "$ep_test" ]] && [[ -f "$path/$ep_test" ]]; then
    has_entrypoints=true
  fi

  echo ""
  if [[ $errors -gt 0 ]]; then
    log_error "Validation failed: $errors error(s), $warnings warning(s)"
    exit 1
  else
    log_success "Component valid: $name v$version ($warnings warning(s))"
  fi
}

# --- New (create) ---
cmd_new() {
  exec "$ARTIFACT_SH" create "$@"
}

# --- Add (register) ---
cmd_add() {
  exec "$ARTIFACT_SH" register "$@"
}

# --- Search ---
cmd_search() {
  if [[ $# -eq 0 ]]; then
    log_error "Usage: rally component search <query> [--limit N]"
    exit 1
  fi
  exec "$SEARCH_SH" "$@"
}

# --- List ---
cmd_list() {
  local filter_capability=""
  local passthrough_args=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --capability) filter_capability="$2"; shift 2;;
      *) passthrough_args+=("$1"); shift;;
    esac
  done

  require_yq

  if [[ -n "$filter_capability" ]]; then
    # Capability-filtered listing
    local cap_lower
    cap_lower=$(echo "$filter_capability" | tr '[:upper:]' '[:lower:]')

    echo "📦 Components providing: $filter_capability"
    echo ""

    local count=0
    for manifest in "$ARTIFACTS_DIR"/*/*/artifact.yaml; do
      [[ -f "$manifest" ]] || continue

      # Check if deprecated
      local deprecated
      deprecated=$(yq -r '.deprecated // false' "$manifest" 2>/dev/null || echo "false")
      [[ "$deprecated" = "true" ]] && continue

      # Check provides
      local caps
      caps=$(yq -r '(.provides // []) | .[].capability' "$manifest" 2>/dev/null || echo "")
      [[ -z "$caps" ]] && continue

      local match=false
      while IFS= read -r cap; do
        local cap_l
        cap_l=$(echo "$cap" | tr '[:upper:]' '[:lower:]')
        if [[ "$cap_l" == *"$cap_lower"* ]]; then
          match=true
          break
        fi
      done <<< "$caps"

      if $match; then
        local name namespace version trust
        name=$(yq -r '.name // .metadata.id // ""' "$manifest")
        namespace=$(yq -r '.namespace // ""' "$manifest")
        version=$(yq -r '.version // .metadata.version // "?"' "$manifest")
        trust=$(yq -r '.trust_tier // .trust.level // "experimental"' "$manifest")

        local trust_icon="🔴"
        case "$trust" in
          verified) trust_icon="🟢";;
          community) trust_icon="🟡";;
        esac

        # Show capabilities
        local all_caps
        all_caps=$(yq -r '(.provides // []) | .[] | "\(.capability) (\(.style // "any"))"' "$manifest" 2>/dev/null)

        echo "  $trust_icon $namespace/$name v$version"
        while IFS= read -r c; do
          echo "     → $c"
        done <<< "$all_caps"
        count=$((count + 1))
      fi
    done

    echo ""
    echo "  Total: $count component(s)"
  else
    # Standard listing via artifact.sh
    if [[ ${#passthrough_args[@]} -gt 0 ]]; then
      exec "$ARTIFACT_SH" list "${passthrough_args[@]}"
    else
      exec "$ARTIFACT_SH" list
    fi
  fi
}

# --- Show ---
cmd_show() {
  exec "$ARTIFACT_SH" show "$@"
}

# --- Resolve ---
cmd_resolve() {
  exec "$RESOLVE_SH" "$@"
}

# --- Help ---
cmd_help() {
  echo "Rally Component Management"
  echo ""
  echo "Usage: rally component <action> [args...]"
  echo ""
  echo "Actions:"
  echo "  validate <path>                   Validate component manifest (provides, compatibility, entrypoints)"
  echo "  new <name> [--type T] [--ns NS]   Create new component from template"
  echo "  add <path>                        Register existing component in registry"
  echo "  search <query> [--limit N]        Search components by text"
  echo "  list [--capability C] [--type T]  List components, optionally by capability"
  echo "  show <id>                         Show component details"
  echo "  resolve <profile> [--format F]    Match project needs to components"
  echo "  help                              Show this help"
  echo ""
  echo "Examples:"
  echo "  rally component validate ./artifacts/io.github.rally-tavern/my-comp"
  echo "  rally component new my-auth-module --type module"
  echo "  rally component search \"fastapi auth\""
  echo "  rally component list --capability user-authentication"
  echo "  rally component resolve project-profile.yaml"
}

# --- Dispatch ---
case "$ACTION" in
  validate)   cmd_validate "$@";;
  new|create) cmd_new "$@";;
  add)        cmd_add "$@";;
  search)     cmd_search "$@";;
  list)       cmd_list "$@";;
  show)       cmd_show "$@";;
  resolve)    cmd_resolve "$@";;
  help|--help|-h) cmd_help;;
  *)
    log_error "Unknown action: $ACTION"
    log_info "Run 'rally component help' for usage"
    exit 1
    ;;
esac
