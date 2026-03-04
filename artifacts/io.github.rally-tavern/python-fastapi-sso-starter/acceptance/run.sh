#!/bin/bash
# Acceptance test for python-fastapi-sso-starter
set -euo pipefail

echo "Running acceptance tests..."

# Check required files exist
for f in app/main.py app/models.py app/auth.py app/config.py app/database.py requirements.txt; do
  [ -f "$f" ] || { echo "❌ Missing: $f"; exit 1; }
done
echo "✓ Required files present"

# Install deps
pip install -q -r requirements.txt 2>/dev/null
echo "✓ Dependencies installed"

# Run tests
pytest tests/ -q
echo "✓ All tests passed"

echo ""
echo "✓ Acceptance tests complete"
