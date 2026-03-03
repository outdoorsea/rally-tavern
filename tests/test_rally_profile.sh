#!/bin/bash
# Tests for Rally Project Profile (Feature 00)
# Usage: ./tests/test_rally_profile.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATE="$REPO_ROOT/scripts/rally-validate-profile.sh"
VALID_PROFILE="$SCRIPT_DIR/fixtures/valid-profile.yaml"
INVALID_PROFILE="$SCRIPT_DIR/fixtures/invalid-profile.yaml"
TEMPLATE="$REPO_ROOT/templates/project-profile.yaml"
FACETS="$REPO_ROOT/defaults/facets.yaml"

PASS=0
FAIL=0

assert_exit() {
  local desc="$1"
  local expected="$2"
  shift 2
  local actual
  set +e
  "$@" > /dev/null 2>&1
  actual=$?
  set -e

  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1"
  local pattern="$2"
  shift 2
  local output
  set +e
  output=$("$@" 2>&1)
  set -e

  if echo "$output" | grep -q "$pattern"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (pattern '$pattern' not found)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Rally Project Profile Tests ==="
echo ""

# --- File existence ---
echo "Files:"
for f in "$VALIDATE" "$TEMPLATE" "$FACETS"; do
  if [[ -f "$f" ]]; then
    echo "  PASS: exists: $(basename "$f")"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: missing: $f"
    FAIL=$((FAIL + 1))
  fi
done

# --- Template structure ---
echo ""
echo "Template structure:"
for key in schema_version project platform language framework facets constraints priorities; do
  if grep -q "^${key}:" "$TEMPLATE" || grep -q "^  ${key}:" "$TEMPLATE"; then
    echo "  PASS: template has '$key'"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: template missing '$key'"
    FAIL=$((FAIL + 1))
  fi
done

# --- Facets vocabulary ---
echo ""
echo "Facets vocabulary:"
for facet in platform language framework auth database api_style deployment ui budget timeline team_size compliance hosting; do
  if grep -q "^${facet}:" "$FACETS"; then
    echo "  PASS: facets has '$facet'"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: facets missing '$facet'"
    FAIL=$((FAIL + 1))
  fi
done

# --- Validation: valid profile ---
echo ""
echo "Validation (valid profile):"
assert_exit "valid profile passes" 0 "$VALIDATE" "$VALID_PROFILE"
assert_contains "valid profile reports success" "Validation passed" "$VALIDATE" "$VALID_PROFILE"

# --- Validation: invalid profile ---
echo ""
echo "Validation (invalid profile):"
assert_exit "invalid profile fails" 1 "$VALIDATE" "$INVALID_PROFILE"
assert_contains "detects missing project.name" "project.name" "$VALIDATE" "$INVALID_PROFILE"
assert_contains "detects missing platform" "platform" "$VALIDATE" "$INVALID_PROFILE"
assert_contains "detects invalid priority" "must be 1-5" "$VALIDATE" "$INVALID_PROFILE"

# --- Validation: missing file ---
echo ""
echo "Validation (edge cases):"
assert_exit "missing file fails" 1 "$VALIDATE" "/nonexistent/profile.yaml"
assert_exit "no args shows usage" 1 "$VALIDATE"

# --- Rally entry point ---
echo ""
echo "Rally entry point:"
RALLY="$REPO_ROOT/scripts/rally.sh"
if [[ -x "$RALLY" ]]; then
  echo "  PASS: rally.sh is executable"
  PASS=$((PASS + 1))
else
  echo "  FAIL: rally.sh not executable"
  FAIL=$((FAIL + 1))
fi
assert_exit "rally help succeeds" 0 "$RALLY" help
assert_contains "rally help shows commands" "init" "$RALLY" help
assert_exit "rally unknown fails" 1 "$RALLY" bogus-command
assert_exit "rally validate runs" 0 "$RALLY" validate "$VALID_PROFILE"

# === Results ===
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if (( FAIL > 0 )); then
  exit 1
fi
