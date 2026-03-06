#!/bin/bash
# Tests for Rally Defaults — Feature 14: Opinionated Stack Defaults
# Usage: ./tests/test_rally_defaults.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULTS_CMD="$REPO_ROOT/scripts/rally-defaults.sh"
STACKS_DIR="$REPO_ROOT/defaults/stacks"
SECURITY_CONTROLS="$REPO_ROOT/defaults/security-controls.yaml"
RALLY="$REPO_ROOT/scripts/rally.sh"

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

echo "=== Rally Defaults Tests (Feature 14) ==="
echo ""

# --- File existence ---
echo "Stack files:"
for stack in python-web ios-swiftui typescript-node; do
  f="$STACKS_DIR/${stack}.yaml"
  if [[ -f "$f" ]]; then
    echo "  PASS: exists: ${stack}.yaml"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: missing: ${stack}.yaml"
    FAIL=$((FAIL + 1))
  fi
done

if [[ -f "$SECURITY_CONTROLS" ]]; then
  echo "  PASS: exists: security-controls.yaml"
  PASS=$((PASS + 1))
else
  echo "  FAIL: missing: security-controls.yaml"
  FAIL=$((FAIL + 1))
fi

# --- Stack YAML structure ---
echo ""
echo "Stack structure (python-web):"
for key in name display_name description platform framework language database testing linting project_structure security_defaults; do
  if grep -q "^${key}:" "$STACKS_DIR/python-web.yaml"; then
    echo "  PASS: python-web has '$key'"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: python-web missing '$key'"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Stack structure (ios-swiftui):"
for key in name display_name description platform framework language architecture testing linting project_structure security_defaults; do
  if grep -q "^${key}:" "$STACKS_DIR/ios-swiftui.yaml"; then
    echo "  PASS: ios-swiftui has '$key'"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ios-swiftui missing '$key'"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Stack structure (typescript-node):"
for key in name display_name description platform framework language database testing linting project_structure security_defaults; do
  if grep -q "^${key}:" "$STACKS_DIR/typescript-node.yaml"; then
    echo "  PASS: typescript-node has '$key'"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: typescript-node missing '$key'"
    FAIL=$((FAIL + 1))
  fi
done

# --- Security controls structure ---
echo ""
echo "Security controls:"
for key in name version description controls; do
  if grep -q "^${key}:" "$SECURITY_CONTROLS"; then
    echo "  PASS: security-controls has '$key'"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: security-controls missing '$key'"
    FAIL=$((FAIL + 1))
  fi
done

for control in access_control cryptography injection insecure_design misconfiguration vulnerable_components authentication data_integrity logging ssrf; do
  if grep -q "  ${control}:" "$SECURITY_CONTROLS"; then
    echo "  PASS: has OWASP control '$control'"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: missing OWASP control '$control'"
    FAIL=$((FAIL + 1))
  fi
done

# --- rally-defaults.sh CLI ---
echo ""
echo "CLI (rally-defaults.sh):"

if [[ -x "$DEFAULTS_CMD" ]]; then
  echo "  PASS: rally-defaults.sh is executable"
  PASS=$((PASS + 1))
else
  echo "  FAIL: rally-defaults.sh not executable"
  FAIL=$((FAIL + 1))
fi

# No args shows usage
assert_exit "no args shows usage" 0 "$DEFAULTS_CMD"
assert_contains "usage mentions list" "list" "$DEFAULTS_CMD"
assert_contains "usage mentions show" "show" "$DEFAULTS_CMD"
assert_contains "usage mentions apply" "apply" "$DEFAULTS_CMD"

# List command
assert_exit "list succeeds" 0 "$DEFAULTS_CMD" list
assert_contains "list shows python-web" "python-web" "$DEFAULTS_CMD" list
assert_contains "list shows ios-swiftui" "ios-swiftui" "$DEFAULTS_CMD" list
assert_contains "list shows typescript-node" "typescript-node" "$DEFAULTS_CMD" list
assert_contains "list mentions security controls" "security-controls" "$DEFAULTS_CMD" list

# Show command
assert_exit "show python-web succeeds" 0 "$DEFAULTS_CMD" show python-web
assert_contains "show python-web has FastAPI" "FastAPI" "$DEFAULTS_CMD" show python-web
assert_exit "show ios-swiftui succeeds" 0 "$DEFAULTS_CMD" show ios-swiftui
assert_contains "show ios-swiftui has SwiftUI" "SwiftUI" "$DEFAULTS_CMD" show ios-swiftui
assert_exit "show typescript-node succeeds" 0 "$DEFAULTS_CMD" show typescript-node
assert_contains "show typescript-node has Fastify" "Fastify" "$DEFAULTS_CMD" show typescript-node

# Show nonexistent stack
assert_exit "show nonexistent fails" 1 "$DEFAULTS_CMD" show nonexistent
assert_contains "show nonexistent mentions error" "not found" "$DEFAULTS_CMD" show nonexistent

# Show with no stack arg
assert_exit "show no args fails" 1 "$DEFAULTS_CMD" show

# Apply with missing args
assert_exit "apply no args fails" 1 "$DEFAULTS_CMD" apply
assert_exit "apply no profile fails" 1 "$DEFAULTS_CMD" apply python-web
assert_exit "apply nonexistent stack fails" 1 "$DEFAULTS_CMD" apply bogus /tmp/p.yaml
assert_exit "apply nonexistent profile fails" 1 "$DEFAULTS_CMD" apply python-web /nonexistent/profile.yaml

# Apply with valid stack and profile
VALID_PROFILE="$SCRIPT_DIR/fixtures/valid-profile.yaml"
if [[ -f "$VALID_PROFILE" ]]; then
  assert_exit "apply with valid args succeeds" 0 "$DEFAULTS_CMD" apply python-web "$VALID_PROFILE"
  assert_contains "apply shows stack name" "python-web" "$DEFAULTS_CMD" apply python-web "$VALID_PROFILE"
fi

# --- Rally entry point routing ---
echo ""
echo "Rally entry point (defaults routing):"
assert_exit "rally defaults succeeds" 0 "$RALLY" defaults
assert_contains "rally defaults list works" "python-web" "$RALLY" defaults list
assert_exit "rally defaults show works" 0 "$RALLY" defaults show python-web

# --- Extensibility: custom stacks discovered ---
echo ""
echo "Extensibility:"
CUSTOM_STACK="$STACKS_DIR/_test-custom.yaml"
cat > "$CUSTOM_STACK" <<'YAML'
name: _test-custom
display_name: Test Custom Stack
description: Temporary test stack
platform: test
YAML

assert_contains "custom stack discovered by list" "_test-custom" "$DEFAULTS_CMD" list
assert_exit "custom stack shown by show" 0 "$DEFAULTS_CMD" show _test-custom

rm -f "$CUSTOM_STACK"
echo "  PASS: custom stack cleanup"
PASS=$((PASS + 1))

# === Results ===
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if (( FAIL > 0 )); then
  exit 1
fi
