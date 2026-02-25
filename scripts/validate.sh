#!/bin/bash
# Validate tavern structure and content
source "$(dirname "$0")/../lib/common.sh"

ERRORS=0

echo "🔍 Validating Rally Tavern"
echo "=========================="
echo ""

# Check required directories
REQUIRED_DIRS=(
  "bounties/open"
  "bounties/claimed"
  "bounties/done"
  "overseers/profiles"
  "mayors"
  "knowledge"
  "coordination"
)

echo "📁 Checking directories..."
for dir in "${REQUIRED_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    echo "  ✓ $dir"
  else
    echo "  ✗ $dir (missing)"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""

# Validate bounty files
echo "📋 Validating bounties..."
for f in bounties/*/*.yaml; do
  [[ -f "$f" ]] || continue
  [[ "$f" =~ gitkeep ]] && continue
  
  # Check required fields
  if ! grep -q "^id:" "$f"; then
    log_error "$f: missing 'id' field"
    ERRORS=$((ERRORS + 1))
  fi
  if ! grep -q "^title:" "$f"; then
    log_error "$f: missing 'title' field"
    ERRORS=$((ERRORS + 1))
  fi
done
echo "  Checked $(find bounties -name "*.yaml" ! -name ".gitkeep" | wc -l | xargs) files"

echo ""

# Validate knowledge files
echo "📚 Validating knowledge..."
for f in knowledge/*/*.yaml; do
  [[ -f "$f" ]] || continue
  [[ "$f" =~ gitkeep ]] && continue
  
  if ! grep -q "^contributed_by:" "$f"; then
    log_warn "$f: missing 'contributed_by' field"
  fi
done
echo "  Checked $(find knowledge -name "*.yaml" ! -name ".gitkeep" | wc -l | xargs) files"

echo ""
echo "=========================="
if [[ $ERRORS -eq 0 ]]; then
  log_success "Validation passed!"
else
  log_error "$ERRORS error(s) found"
  exit 1
fi
