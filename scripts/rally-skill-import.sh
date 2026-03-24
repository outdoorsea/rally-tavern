#!/bin/bash
# Rally Skill Import — Convert SKILL.md (Agent Skills spec) to Rally YAML
#
# Reads the SKILL.md format (YAML frontmatter + Markdown body) used by
# github/awesome-copilot, VoltAgent, Claude Code skills, etc. and converts
# to Rally Tavern's native skill YAML format.
#
# Usage:
#   rally-skill-import.sh <path-or-dir> [--output <dir>] [--dry-run] [--force]
#   rally-skill-import.sh --from-repo <github-org/repo> [--skills <name1,name2,...>] [--output <dir>]
#
# Examples:
#   rally-skill-import.sh ./my-skill/SKILL.md              # Import single skill
#   rally-skill-import.sh ./skills-collection/              # Import all skills in dir
#   rally-skill-import.sh --from-repo github/awesome-copilot --skills agent-governance,code-review

set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

SKILLS_DIR="$TAVERN_ROOT/skills"
OUTPUT_DIR=""
DRY_RUN=false
FORCE=false
FROM_REPO=""
SKILL_FILTER=""

# --- Argument parsing ---

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)     OUTPUT_DIR="${2:-}"; shift 2;;
    --dry-run)    DRY_RUN=true; shift;;
    --force)      FORCE=true; shift;;
    --from-repo)  FROM_REPO="${2:-}"; shift 2;;
    --skills)     SKILL_FILTER="${2:-}"; shift 2;;
    --help|-h)
      echo "Rally Skill Import — Convert SKILL.md to Rally YAML"
      echo ""
      echo "Usage:"
      echo "  rally skill import <path>              Import SKILL.md or directory of skills"
      echo "  rally skill import --from-repo <repo>  Import from GitHub repository"
      echo ""
      echo "Options:"
      echo "  --output <dir>         Output directory (default: skills/)"
      echo "  --dry-run              Show what would be imported without writing"
      echo "  --force                Overwrite existing skills"
      echo "  --from-repo <repo>     GitHub org/repo to fetch from (e.g., github/awesome-copilot)"
      echo "  --skills <list>        Comma-separated skill names to import (with --from-repo)"
      echo ""
      echo "The SKILL.md format (agentskills.io spec) uses YAML frontmatter with"
      echo "name + description, and a Markdown body containing instructions."
      echo "This converter wraps that into Rally's YAML skill format."
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

OUTPUT_DIR="${OUTPUT_DIR:-$SKILLS_DIR}"

# --- Core conversion ---

# Parse SKILL.md frontmatter and body
parse_skill_md() {
  local file="$1"
  local in_frontmatter=false
  local past_frontmatter=false
  local frontmatter=""
  local body=""

  while IFS= read -r line; do
    if [[ "$line" == "---" ]] && ! $past_frontmatter; then
      if $in_frontmatter; then
        # End of frontmatter
        in_frontmatter=false
        past_frontmatter=true
      else
        # Start of frontmatter
        in_frontmatter=true
      fi
      continue
    fi

    if $in_frontmatter; then
      frontmatter+="$line"$'\n'
    elif $past_frontmatter; then
      body+="$line"$'\n'
    fi
  done < "$file"

  echo "FRONTMATTER_START"
  echo "$frontmatter"
  echo "FRONTMATTER_END"
  echo "BODY_START"
  echo "$body"
  echo "BODY_END"
}

# Extract a value from parsed frontmatter (simple key: value)
fm_get() {
  local frontmatter="$1" key="$2"
  echo "$frontmatter" | grep "^${key}:" | head -1 | sed "s/^${key}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//'
}

# Extract multi-line description (handles | and multi-line values)
fm_get_description() {
  local frontmatter="$1"
  local in_desc=false
  local desc=""
  local first_line=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^description: ]]; then
      first_line=$(echo "$line" | sed 's/^description:[[:space:]]*//')
      if [[ "$first_line" == "|" ]] || [[ -z "$first_line" ]]; then
        in_desc=true
        continue
      else
        # Single-line description
        echo "$first_line" | sed 's/^"//' | sed 's/"$//'
        return
      fi
    elif $in_desc; then
      # Multi-line: stop at next top-level key
      if [[ "$line" =~ ^[a-z] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
        break
      fi
      desc+="$(echo "$line" | sed 's/^[[:space:]]*//')"$'\n'
    fi
  done <<< "$frontmatter"

  if [[ -n "$desc" ]]; then
    # Trim trailing newlines and take first meaningful line for the description field
    echo "$desc" | head -1 | sed 's/[[:space:]]*$//'
  fi
}

# Convert a single SKILL.md to Rally YAML
convert_skill() {
  local skill_md="$1"
  local output_dir="$2"

  # Parse the file
  local parsed
  parsed=$(parse_skill_md "$skill_md")

  local frontmatter body
  frontmatter=$(echo "$parsed" | sed -n '/^FRONTMATTER_START$/,/^FRONTMATTER_END$/p' | sed '1d;$d')
  body=$(echo "$parsed" | sed -n '/^BODY_START$/,/^BODY_END$/p' | sed '1d;$d')

  if [[ -z "$frontmatter" ]]; then
    log_error "No YAML frontmatter found in: $skill_md"
    return 1
  fi

  # Extract fields
  local name description license compatibility
  name=$(fm_get "$frontmatter" "name")
  description=$(fm_get_description "$frontmatter")
  license=$(fm_get "$frontmatter" "license")
  compatibility=$(fm_get "$frontmatter" "compatibility")

  if [[ -z "$name" ]]; then
    log_error "Skill has no name: $skill_md"
    return 1
  fi

  if [[ -z "$description" ]]; then
    log_warn "Skill has no description: $name"
    description="Imported from SKILL.md"
  fi

  # Truncate description for the YAML field (first sentence or 200 chars)
  local short_desc
  short_desc=$(echo "$description" | head -1 | cut -c1-200)

  # Check for existing skill
  local output_file="$output_dir/${name}.yaml"
  if [[ -f "$output_file" ]] && ! $FORCE; then
    log_warn "Skill already exists: $name (use --force to overwrite)"
    return 0
  fi

  if $DRY_RUN; then
    log_info "[dry-run] Would import: $name → $output_file"
    echo "  Source: $skill_md"
    echo "  Description: $short_desc"
    return 0
  fi

  # Check for bundled assets
  local skill_dir
  skill_dir=$(dirname "$skill_md")
  local has_scripts=false has_references=false
  [[ -d "$skill_dir/scripts" ]] && has_scripts=true
  [[ -d "$skill_dir/references" ]] && has_references=true

  # Build the reference context for the prompt
  local reference_note=""
  if $has_scripts || $has_references; then
    reference_note=$'\n'
    reference_note+="    # Note: This skill was imported from a SKILL.md with bundled assets."$'\n'
    $has_scripts && reference_note+="    # Original scripts directory: $(realpath "$skill_dir/scripts" 2>/dev/null || echo "$skill_dir/scripts")"$'\n'
    $has_references && reference_note+="    # Original references directory: $(realpath "$skill_dir/references" 2>/dev/null || echo "$skill_dir/references")"$'\n'
  fi

  # Escape the body for YAML embedding (indent by 4 spaces for the prompt block)
  local indented_body
  indented_body=$(echo "$body" | sed 's/^/    /')

  # Build the rally YAML skill
  mkdir -p "$output_dir"
  cat > "$output_file" << YAML_EOF
# Rally Skill: ${name}
# Imported from SKILL.md (Agent Skills spec)
# Source: ${skill_md}
# Import date: $(date -u +%Y-%m-%d)
$([ -n "$license" ] && echo "# License: ${license}")

name: ${name}
version: 1
description: "${short_desc}"
$([ -n "$compatibility" ] && echo "compatibility: \"${compatibility}\"")

input:
  required:
    - project-profile
  optional:
    - context

prompt:
  system: |
    You are an expert following the instructions below.
    Apply these instructions to the project profile provided.

    Rules:
    - Output ONLY valid YAML. No markdown, no commentary, no explanation.
    - Every field must be filled. Empty lists are not acceptable.
    - Derive everything from the project profile and context provided.
${reference_note}
  user: |
    Apply the following skill instructions to this project:

    PROJECT PROFILE:
    {{project-profile}}

    {{context}}

    SKILL INSTRUCTIONS:
${indented_body}
    Output strict YAML with your findings. Use descriptive top-level keys
    that match the categories in the instructions above.
    Output ONLY the YAML. No fences, no preamble, no explanation.

output:
  format: yaml
  required_keys:
    - summary
    - findings
    - recommendations
YAML_EOF

  log_success "Imported: $name → $output_file"
  return 0
}

# --- Import from GitHub repo ---

import_from_repo() {
  local repo="$1"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  log_info "Fetching skill list from $repo..."

  # Get skill directories
  local skills_list
  if ! skills_list=$(gh api "repos/${repo}/contents/skills" --jq '.[].name' 2>&1); then
    log_error "Failed to list skills from $repo: $skills_list"
    return 1
  fi

  # Apply filter if specified
  if [[ -n "$SKILL_FILTER" ]]; then
    local filtered=""
    IFS=',' read -ra FILTER_NAMES <<< "$SKILL_FILTER"
    for skill_name in $skills_list; do
      for filter in "${FILTER_NAMES[@]}"; do
        if [[ "$skill_name" == "$filter" ]]; then
          filtered+="$skill_name"$'\n'
        fi
      done
    done
    skills_list="$filtered"
  fi

  if [[ -z "$skills_list" ]]; then
    log_error "No matching skills found in $repo"
    return 1
  fi

  local count=0 total
  total=$(echo "$skills_list" | grep -c . || true)
  log_info "Found $total skills to process"

  while IFS= read -r skill_name; do
    [[ -z "$skill_name" ]] && continue

    # Fetch SKILL.md content
    local skill_file="$tmpdir/${skill_name}/SKILL.md"
    mkdir -p "$tmpdir/${skill_name}"

    local content
    if content=$(gh api "repos/${repo}/contents/skills/${skill_name}/SKILL.md" --jq '.content' 2>/dev/null); then
      echo "$content" | base64 -d > "$skill_file" 2>/dev/null
      if convert_skill "$skill_file" "$OUTPUT_DIR"; then
        count=$((count + 1))
      fi
    else
      log_warn "Could not fetch SKILL.md for: $skill_name"
    fi
  done <<< "$skills_list"

  log_success "Imported $count/$total skills from $repo"
}

# --- Import from local path ---

import_local() {
  local path="$1"

  if [[ -f "$path" ]]; then
    # Single file
    if [[ "$(basename "$path")" == "SKILL.md" ]]; then
      convert_skill "$path" "$OUTPUT_DIR"
    else
      log_error "Expected SKILL.md, got: $(basename "$path")"
      return 1
    fi
  elif [[ -d "$path" ]]; then
    # Check if this IS a skill directory (has SKILL.md)
    if [[ -f "$path/SKILL.md" ]]; then
      convert_skill "$path/SKILL.md" "$OUTPUT_DIR"
      return $?
    fi

    # Otherwise scan for skill subdirectories
    local count=0
    local found=0

    for skill_dir in "$path"/*/; do
      [[ -d "$skill_dir" ]] || continue
      if [[ -f "${skill_dir}SKILL.md" ]]; then
        found=$((found + 1))
        if convert_skill "${skill_dir}SKILL.md" "$OUTPUT_DIR"; then
          count=$((count + 1))
        fi
      fi
    done

    if [[ $found -eq 0 ]]; then
      log_error "No SKILL.md files found in: $path"
      return 1
    fi

    log_success "Imported $count/$found skills from $path"
  else
    log_error "Path not found: $path"
    return 1
  fi
}

# --- Main ---

if [[ -n "$FROM_REPO" ]]; then
  import_from_repo "$FROM_REPO"
elif [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  import_local "${POSITIONAL[0]}"
else
  log_error "Usage: rally skill import <path> or rally skill import --from-repo <org/repo>"
  log_info "Run 'rally skill import --help' for details"
  exit 1
fi
