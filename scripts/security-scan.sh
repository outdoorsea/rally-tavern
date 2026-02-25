#!/bin/bash
# Comprehensive security scanner
source "$(dirname "$0")/../lib/common.sh"

SCAN_DIR="${1:-.}"
ISSUES=0
SCANNED=0

echo "🛡️ Security Scan: $SCAN_DIR"
echo "================================"
echo ""

# Injection patterns
INJECTION_PATTERNS=(
  "ignore.*previous.*instruction"
  "ignore.*all.*instruction"
  "disregard.*instruction"
  "forget.*instruction"
  "new.*instruction"
  "system.*prompt"
  "you.*are.*now"
  "pretend.*you"
  "act.*as.*if"
  "roleplay.*as"
)

# Dangerous patterns
DANGEROUS_PATTERNS=(
  "eval("
  "exec("
  "\\\$("
  "base64.*decode"
  "curl.*\\|.*sh"
  "wget.*\\|.*sh"
  "rm.*-rf"
)

# Scan file
scan_file() {
  local file="$1"
  local file_issues=0
  
  SCANNED=$((SCANNED + 1))
  
  # Check injection patterns
  for pattern in "${INJECTION_PATTERNS[@]}"; do
    if grep -qi "$pattern" "$file" 2>/dev/null; then
      log_warn "INJECTION: $file"
      echo "   Pattern: $pattern"
      grep -ni "$pattern" "$file" | head -2 | sed 's/^/   /'
      file_issues=$((file_issues + 1))
    fi
  done
  
  # Check dangerous patterns
  for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if grep -qE "$pattern" "$file" 2>/dev/null; then
      log_warn "DANGEROUS: $file"
      echo "   Pattern: $pattern"
      file_issues=$((file_issues + 1))
    fi
  done
  
  # Check for hidden HTML comments
  if grep -q "<!--.*-->" "$file" 2>/dev/null; then
    log_warn "HIDDEN CONTENT: $file"
    echo "   HTML comments found (could hide malicious content)"
    file_issues=$((file_issues + 1))
  fi
  
  # Check for non-ASCII (potential unicode tricks)
  if grep -P '[^\x00-\x7F]' "$file" >/dev/null 2>&1; then
    # Allow common UTF-8 characters like emojis in specific files
    if [[ ! "$file" =~ (README|HALL_OF_FAME|wisdom) ]]; then
      log_info "NON-ASCII: $file (review manually)"
    fi
  fi
  
  ISSUES=$((ISSUES + file_issues))
}

# Scan directory
find "$SCAN_DIR" -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.md" -o -name "*.json" \) | while read -r file; do
  # Skip hidden and git
  [[ "$file" =~ \.git ]] && continue
  scan_file "$file"
done

echo ""
echo "================================"
echo "Scanned: $SCANNED files"
if [[ $ISSUES -eq 0 ]]; then
  log_success "No security issues found!"
else
  log_error "Found $ISSUES issue(s)"
  exit 1
fi
