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
    ARTIFACTS_FOUND=0
    while IFS= read -r -d '' file; do
      # Track artifact.yaml files for awareness
      if [ "$(basename "$file")" = "artifact.yaml" ]; then
        ARTIFACTS_FOUND=$((ARTIFACTS_FOUND + 1))
      fi

      result=$(scan_file "$file")
      if [ -n "$result" ]; then
        echo "📄 $file"
        echo "$result"
        echo ""
        ((ISSUES++))
      fi
    done < <(find "$DIR" -type f \( -name "*.md" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) -not -path "*/.git/*" -print0)

    if [ $ISSUES -eq 0 ]; then
      echo "✅ No suspicious patterns found"
    else
      echo "⚠️  Found issues in $ISSUES file(s)"
    fi

    if [ $ARTIFACTS_FOUND -gt 0 ]; then
      echo ""
      echo "📦 Found $ARTIFACTS_FOUND artifact(s). Use 'security.sh scan-artifact <id>' for detailed artifact scanning."
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
    
  scan-artifact)
    ARTIFACT_ID="$1"
    [ -z "$ARTIFACT_ID" ] && echo "Usage: security.sh scan-artifact <namespace/name>" && exit 1

    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    ARTIFACTS_DIR="${ARTIFACT_DIR_OVERRIDE:-$ROOT_DIR/artifacts}"
    ARTIFACT_DIR="$ARTIFACTS_DIR/$ARTIFACT_ID"

    [ ! -d "$ARTIFACT_DIR" ] && echo "Artifact not found: $ARTIFACT_ID" && exit 1
    [ ! -f "$ARTIFACT_DIR/artifact.yaml" ] && echo "No artifact.yaml in: $ARTIFACT_DIR" && exit 1

    echo "🛡️ Scanning artifact: $ARTIFACT_ID"
    echo ""

    ISSUES=0
    SCANNED=0
    while IFS= read -r -d '' file; do
      SCANNED=$((SCANNED + 1))
      result=$(scan_file "$file")
      if [ -n "$result" ]; then
        echo "📄 $file"
        echo "$result"
        echo ""
        ((ISSUES++))
      fi
    done < <(find "$ARTIFACT_DIR" -type f \( -name "*.md" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.sh" -o -name "*.py" -o -name "*.js" -o -name "*.ts" \) -not -path "*/.git/*" -print0)

    # Determine scan status
    if [ $ISSUES -eq 0 ]; then
      SCAN_STATUS="passed"
      echo "✅ Artifact scan passed ($SCANNED files scanned)"
    else
      SCAN_STATUS="failed"
      echo "⚠️  Artifact scan failed: $ISSUES file(s) with issues ($SCANNED scanned)"
    fi

    # Generate report
    REPORT_ID="scan-$(date +%Y%m%d)-$(openssl rand -hex 4)"
    mkdir -p security/reports

    cat > "security/reports/${REPORT_ID}.json" << REPORT
{
  "id": "$REPORT_ID",
  "artifact": "$ARTIFACT_ID",
  "scanned_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scanned_by": "$(git config user.name)",
  "scanner": "rally-security-scan",
  "status": "$SCAN_STATUS",
  "files_scanned": $SCANNED,
  "issues_found": $ISSUES
}
REPORT
    git add "security/reports/${REPORT_ID}.json"

    # Update artifact.yaml trust.security section
    if command -v yq >/dev/null 2>&1; then
      MANIFEST="$ARTIFACT_DIR/artifact.yaml"
      SCAN_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

      yq -i ".trust.security.lastScanAt = \"$SCAN_TIME\"" "$MANIFEST"
      yq -i ".trust.security.scanners = [{\"name\": \"rally-security-scan\", \"status\": \"$SCAN_STATUS\", \"report\": \"security/reports/${REPORT_ID}.json\"}]" "$MANIFEST"

      # Also update legacy securityScans field if present
      yq -i ".trust.securityScans.lastScan = \"$SCAN_TIME\"" "$MANIFEST"
      yq -i ".trust.securityScans.scanner = \"rally-security-scan\"" "$MANIFEST"
      yq -i ".trust.securityScans.status = \"$([ "$SCAN_STATUS" = "passed" ] && echo "pass" || echo "fail")\"" "$MANIFEST"

      git add "$MANIFEST"
      echo ""
      echo "✓ Updated artifact trust.security in $MANIFEST"
      echo "✓ Report: security/reports/${REPORT_ID}.json"
    else
      echo ""
      echo "⚠️  yq not found — artifact.yaml not updated (report saved)"
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
    echo "  scan [dir]                       - Scan directory for issues"
    echo "  scan-artifact <namespace/name>   - Scan artifact and update trust"
    echo "  check <file>                     - Check specific file"
    echo "  report <file> <concern>          - Report suspicious content"
    ;;
esac
