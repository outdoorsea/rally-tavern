#!/bin/bash
# Rally Tavern - Common functions
# Source this in scripts: source "$(dirname "$0")/../lib/common.sh"

set -euo pipefail  # Strict mode

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

# Get repo root
TAVERN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Validate YAML exists
require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    log_error "File not found: $file"
    exit 1
  fi
}

# Get current user identity
get_identity() {
  local overseer mayor
  overseer=$(find "$TAVERN_ROOT/overseers/profiles" -name "*.yaml" 2>/dev/null | head -1 | xargs -I{} basename {} .yaml 2>/dev/null || echo "")
  mayor=$(find "$TAVERN_ROOT/mayors" -name "*.yaml" ! -name ".gitkeep" 2>/dev/null | head -1 | xargs -I{} basename {} .yaml 2>/dev/null || echo "")
  
  if [[ -n "$mayor" ]]; then
    echo "mayor:$mayor"
  elif [[ -n "$overseer" ]]; then
    echo "overseer:$overseer"
  else
    echo "unknown:anonymous"
  fi
}

# Extract YAML value (simple, no dependencies)
yaml_get() {
  local file="$1" key="$2"
  grep "^${key}:" "$file" 2>/dev/null | head -1 | cut -d: -f2- | xargs
}

# Generate ID
generate_id() {
  local prefix="${1:-item}"
  echo "${prefix}-$(openssl rand -hex 4)"
}

# ISO timestamp
timestamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# Validate bounty ID format
validate_bounty_id() {
  local id="$1"
  if [[ ! "$id" =~ ^bounty-[a-f0-9]{8}$ ]] && [[ ! "$id" =~ ^bounty-example ]]; then
    log_warn "Non-standard bounty ID format: $id"
  fi
}

# Check for common security issues in a file
security_check() {
  local file="$1"
  local issues=0
  
  # Patterns that might indicate prompt injection
  local patterns=(
    "ignore.*previous.*instruction"
    "ignore.*all.*instruction"
    "disregard.*instruction"
    "system.*prompt"
    "you.*are.*now"
    "pretend.*you"
  )
  
  for pattern in "${patterns[@]}"; do
    if grep -qi "$pattern" "$file" 2>/dev/null; then
      log_warn "Suspicious pattern in $file: $pattern"
      issues=$((issues + 1))
    fi
  done
  
  # Check for hidden content
  if grep -q "<!--" "$file" 2>/dev/null; then
    log_warn "HTML comments found in $file (could hide content)"
    issues=$((issues + 1))
  fi
  
  return $issues
}
