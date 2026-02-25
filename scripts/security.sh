#!/bin/bash
# Rally Tavern Security Scanner

ACTION="$1"
shift

# Patterns that might indicate prompt injection
SUSPICIOUS_PATTERNS=(
  "ignore.*previous.*instruction"
  "ignore.*all.*instruction"
  "disregard.*instruction"
  "forget.*instruction"
  "new.*instruction"
  "system.*prompt"
  "you.*are.*now"
  "pretend.*you.*are"
  "act.*as.*if"
  "base64"
  "eval("
  "exec("
  "<!--.*-->"  # HTML comments (can hide content)
  "curl.*http"
  "wget.*http"
  "exfiltrate"
  "\$\(.*\)"   # Command substitution
)

scan_file() {
  FILE="$1"
  FOUND=0
  
  for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
    if grep -qi "$pattern" "$FILE" 2>/dev/null; then
      echo "  ⚠️  Suspicious pattern: $pattern"
      grep -ni "$pattern" "$FILE" | head -3
      FOUND=1
    fi
  done
  
  # Check for hidden unicode
  if grep -P '[^\x00-\x7F]' "$FILE" >/dev/null 2>&1; then
    echo "  ⚠️  Contains non-ASCII characters (review manually)"
    FOUND=1
  fi
  
  return $FOUND
}

case "$ACTION" in
  scan)
    DIR="${1:-.}"
    echo "🛡️ Scanning $DIR for security issues..."
    echo ""
    
    ISSUES=0
    while IFS= read -r -d '' file; do
      result=$(scan_file "$file")
      if [ -n "$result" ]; then
        echo "📄 $file"
        echo "$result"
        echo ""
        ((ISSUES++))
      fi
    done < <(find "$DIR" -type f \( -name "*.md" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) -print0)
    
    if [ $ISSUES -eq 0 ]; then
      echo "✅ No suspicious patterns found"
    else
      echo "⚠️  Found issues in $ISSUES file(s)"
    fi
    ;;
    
  check)
    FILE="$1"
    if [ ! -f "$FILE" ]; then
      echo "File not found: $FILE"
      exit 1
    fi
    
    echo "🛡️ Checking: $FILE"
    result=$(scan_file "$FILE")
    if [ -n "$result" ]; then
      echo "$result"
      exit 1
    else
      echo "✅ No issues found"
    fi
    ;;
    
  report)
    FILE="$1"
    CONCERN="$2"
    
    REPORT_ID="report-$(date +%Y%m%d)-$(openssl rand -hex 4)"
    mkdir -p security/reports
    
    cat > "security/reports/${REPORT_ID}.yaml" << EOF
id: $REPORT_ID
file: $FILE
reported_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
reported_by: $(git config user.name)
concern: |
  $CONCERN
status: open
EOF
    
    echo "✓ Reported: $REPORT_ID"
    git add "security/reports/${REPORT_ID}.yaml"
    ;;
    
  *)
    echo "Usage: security.sh <action> [args]"
    echo ""
    echo "Actions:"
    echo "  scan [dir]              - Scan directory for issues"
    echo "  check <file>            - Check specific file"
    echo "  report <file> <concern> - Report suspicious content"
    ;;
esac
