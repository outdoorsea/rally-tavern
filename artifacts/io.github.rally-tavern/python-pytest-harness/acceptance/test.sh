#!/bin/bash
set -euo pipefail

# Verify required files exist
[ -f "artifact.yaml" ] || { echo "FAIL: missing artifact.yaml"; exit 1; }
[ -d "templates" ] || { echo "FAIL: missing templates/"; exit 1; }
[ -f "templates/conftest.py" ] || { echo "FAIL: missing templates/conftest.py"; exit 1; }
[ -f "templates/requirements-test.txt" ] || { echo "FAIL: missing templates/requirements-test.txt"; exit 1; }
[ -f "templates/pytest.ini" ] || { echo "FAIL: missing templates/pytest.ini"; exit 1; }

# Verify manifest has required fields
command -v yq >/dev/null 2>&1 || { echo "SKIP: yq not available"; exit 0; }
name=$(yq -r '.name // ""' artifact.yaml)
[ -n "$name" ] || { echo "FAIL: manifest missing name"; exit 1; }

provides=$(yq -r '(.provides // []) | length' artifact.yaml)
[ "$provides" -gt 0 ] || { echo "FAIL: manifest missing provides"; exit 1; }

echo "PASS: python-pytest-harness validation"
