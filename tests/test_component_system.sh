#!/bin/bash
# Tests for Component System (Features 11, 12, 13)
# Usage: ./tests/test_component_system.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPONENT_SH="$REPO_ROOT/scripts/rally-component.sh"
RESOLVE_SH="$REPO_ROOT/scripts/component-resolve.sh"
ARTIFACT_SH="$REPO_ROOT/scripts/artifact.sh"
RALLY="$REPO_ROOT/scripts/rally.sh"
ARTIFACTS_DIR="$REPO_ROOT/artifacts"
FIXTURES="$SCRIPT_DIR/fixtures"

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
    echo "  FAIL: $desc (pattern '$pattern' not found in output)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local desc="$1"
  local pattern="$2"
  shift 2
  local output
  set +e
  output=$("$@" 2>&1)
  set -e

  if ! echo "$output" | grep -q "$pattern"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (pattern '$pattern' should NOT be in output)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Component System Tests (Features 11, 12, 13) ==="
echo ""

# -------------------------------------------------------
echo "--- Feature 11: Component Manifest & Validation ---"
echo ""

# Test: rally component help
assert_exit "rally component help exits 0" 0 "$COMPONENT_SH" help
assert_contains "rally component help shows actions" "validate" "$COMPONENT_SH" help

# Test: rally.sh routes component command
assert_exit "rally component routes correctly" 0 "$RALLY" component help

# Test: validate existing valid component
assert_exit "validate valid component (python-fastapi-sso-starter)" 0 \
  "$COMPONENT_SH" validate "$ARTIFACTS_DIR/io.github.rally-tavern/python-fastapi-sso-starter"

assert_exit "validate valid component (ios-swift-auth-settings-starter)" 0 \
  "$COMPONENT_SH" validate "$ARTIFACTS_DIR/io.github.rally-tavern/ios-swift-auth-settings-starter"

assert_exit "validate valid component (python-pytest-harness)" 0 \
  "$COMPONENT_SH" validate "$ARTIFACTS_DIR/io.github.rally-tavern/python-pytest-harness"

# Test: validate detects missing manifest
TMP_DIR=$(mktemp -d)
assert_exit "validate fails on missing manifest" 1 "$COMPONENT_SH" validate "$TMP_DIR"
rm -rf "$TMP_DIR"

# Test: validate shows success message
assert_contains "validate shows component name" "python-pytest-harness" \
  "$COMPONENT_SH" validate "$ARTIFACTS_DIR/io.github.rally-tavern/python-pytest-harness"

# Test: rally.sh routes resolve command
assert_exit "rally resolve routes correctly" 0 "$RALLY" resolve --help

echo ""

# -------------------------------------------------------
echo "--- Feature 12: Component Resolution Engine ---"
echo ""

# Create temp profile for testing
TEMP_PROFILE=$(mktemp /tmp/test-profile-XXXXXX.yaml)
cat > "$TEMP_PROFILE" <<'PROFILE'
schema_version: 1
project:
  name: "Test Project"
  slug: "test-project"
  description: "A test project for resolution testing"
platform: python-web
language: python
framework: fastapi
facets:
  auth: oauth2
  database: postgres
  api_style: rest
  deployment: docker
  ui: none
constraints:
  budget: startup
  timeline: sprint
  team_size: solo
priorities:
  speed_to_market: 2
  scalability: 3
  security: 3
  maintainability: 3
  developer_experience: 2
PROFILE

# Test: resolve finds python components for python profile
assert_exit "resolve runs successfully with profile" 0 "$RESOLVE_SH" "$TEMP_PROFILE"
assert_contains "resolve finds fastapi starter" "python-fastapi-sso-starter" \
  "$RESOLVE_SH" "$TEMP_PROFILE"
assert_contains "resolve finds pytest harness" "python-pytest-harness" \
  "$RESOLVE_SH" "$TEMP_PROFILE"

# Test: resolve filters out incompatible platforms
assert_not_contains "resolve excludes iOS component for Python profile" "ios-swift" \
  "$RESOLVE_SH" "$TEMP_PROFILE"

# Test: resolve with capability filter
assert_contains "resolve with --capability finds auth component" "python-fastapi-sso-starter" \
  "$RESOLVE_SH" "$TEMP_PROFILE" --capability user-authentication
assert_not_contains "resolve --capability auth excludes non-auth" "python-pytest-harness" \
  "$RESOLVE_SH" "$TEMP_PROFILE" --capability user-authentication

# Test: resolve JSON format
assert_contains "resolve --format json outputs JSON" '"components"' \
  "$RESOLVE_SH" "$TEMP_PROFILE" --format json

# Test: resolve with iOS profile excludes python components
IOS_PROFILE=$(mktemp /tmp/test-ios-profile-XXXXXX.yaml)
cat > "$IOS_PROFILE" <<'PROFILE'
schema_version: 1
project:
  name: "iOS Test"
  slug: "ios-test"
platform: ios-swiftui
language: swift
framework: swiftui
facets:
  auth: session
  database: none
  api_style: none
  deployment: local
  ui: mobile-native
PROFILE

assert_contains "resolve iOS profile finds swift starter" "ios-swift" \
  "$RESOLVE_SH" "$IOS_PROFILE"
assert_not_contains "resolve iOS profile excludes python" "python-fastapi" \
  "$RESOLVE_SH" "$IOS_PROFILE"

# Test: resolve fails on missing profile
assert_exit "resolve fails on nonexistent profile" 1 "$RESOLVE_SH" /nonexistent.yaml

# Test: resolve shows help
assert_exit "resolve --help exits 0" 0 "$RESOLVE_SH" --help

# Cleanup temp files
rm -f "$TEMP_PROFILE" "$IOS_PROFILE"

echo ""

# -------------------------------------------------------
echo "--- Feature 13: Component Registry ---"
echo ""

# Test: component list works
assert_exit "component list exits 0" 0 "$COMPONENT_SH" list
assert_contains "component list shows artifacts" "Artifact Registry" "$COMPONENT_SH" list

# Test: component list with capability filter
assert_contains "list --capability shows matching components" "user-authentication" \
  "$COMPONENT_SH" list --capability user-authentication

# Test: component search works
assert_exit "component search exits 0" 0 "$COMPONENT_SH" search "python"
assert_contains "search finds python components" "python" "$COMPONENT_SH" search "python"

# Test: component show works
assert_exit "component show exits 0" 0 \
  "$COMPONENT_SH" show io.github.rally-tavern/python-pytest-harness
assert_contains "show displays component name" "python-pytest-harness" \
  "$COMPONENT_SH" show io.github.rally-tavern/python-pytest-harness

# Test: registry index exists and has entries
if [[ -f "$ARTIFACTS_DIR/.index.json" ]]; then
  entry_count=$(jq '. | length' "$ARTIFACTS_DIR/.index.json")
  if [[ "$entry_count" -ge 3 ]]; then
    echo "  PASS: Registry index has $entry_count entries (>= 3 seed components)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Registry index has only $entry_count entries (expected >= 3)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  FAIL: Registry index .index.json not found"
  FAIL=$((FAIL + 1))
fi

# Test: REGISTRY.md exists
if [[ -f "$REPO_ROOT/REGISTRY.md" ]]; then
  echo "  PASS: REGISTRY.md exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: REGISTRY.md not found"
  FAIL=$((FAIL + 1))
fi

# Test: seed components exist
for comp in python-fastapi-sso-starter ios-swift-auth-settings-starter python-pytest-harness; do
  if [[ -f "$ARTIFACTS_DIR/io.github.rally-tavern/$comp/artifact.yaml" ]]; then
    echo "  PASS: Seed component exists: $comp"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Seed component missing: $comp"
    FAIL=$((FAIL + 1))
  fi
done

# Test: acceptance tests exist for seed components
for comp in python-fastapi-sso-starter ios-swift-auth-settings-starter python-pytest-harness; do
  if [[ -f "$ARTIFACTS_DIR/io.github.rally-tavern/$comp/acceptance/test.sh" ]]; then
    echo "  PASS: Acceptance test exists: $comp"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Acceptance test missing: $comp"
    FAIL=$((FAIL + 1))
  fi
done

# Test: new component creation and cleanup
TMP_NS="io.github.rally-tavern"
TMP_NAME="test-temp-component-$(openssl rand -hex 4)"
assert_exit "component new creates successfully" 0 \
  "$COMPONENT_SH" new "$TMP_NAME" --namespace "$TMP_NS"

if [[ -d "$ARTIFACTS_DIR/$TMP_NS/$TMP_NAME" ]]; then
  echo "  PASS: New component directory created"
  PASS=$((PASS + 1))

  # Newly scaffolded components have empty provides fields, so validation
  # correctly reports errors. Verify artifact.sh validate (basic) passes.
  assert_exit "new component passes basic artifact validation" 0 \
    "$ARTIFACT_SH" validate "$ARTIFACTS_DIR/$TMP_NS/$TMP_NAME"

  # Cleanup
  rm -rf "$ARTIFACTS_DIR/$TMP_NS/$TMP_NAME"
  "$ARTIFACT_SH" reindex > /dev/null 2>&1
else
  echo "  FAIL: New component directory not created"
  FAIL=$((FAIL + 1))
fi

echo ""

# -------------------------------------------------------
echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "FAILED"
  exit 1
else
  echo "ALL TESTS PASSED"
  exit 0
fi
