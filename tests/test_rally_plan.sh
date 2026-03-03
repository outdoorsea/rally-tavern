#!/bin/bash
# Tests for Rally Plan — Build Card Generation (Feature 10)
# Usage: ./tests/test_rally_plan.sh
#
# Tests the orchestrator script, build card assembly, graceful degradation,
# and rally CLI integration. Does NOT invoke Claude (uses mock skill outputs).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN_RUNNER="$REPO_ROOT/scripts/rally-plan.sh"
RALLY="$REPO_ROOT/scripts/rally.sh"
VALID_PROFILE="$SCRIPT_DIR/fixtures/valid-profile.yaml"
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
    echo "  FAIL: $desc (pattern '$pattern' not found)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_contains() {
  local desc="$1"
  local file="$2"
  local pattern="$3"

  if [[ ! -f "$file" ]]; then
    echo "  FAIL: $desc (file not found: $file)"
    FAIL=$((FAIL + 1))
    return
  fi

  if grep -q "$pattern" "$file"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (pattern '$pattern' not in $file)"
    FAIL=$((FAIL + 1))
  fi
}

# Create a mock skill runner script
# Args: $1=output_dir, $2...=skill names that should succeed
create_mock_runner() {
  local mock_dir="$1"
  shift
  local succeed_skills=("$@")

  local mock_script="${mock_dir}/mock-skill-runner.sh"
  cat > "$mock_script" << 'INNEREOF'
#!/bin/bash
set -euo pipefail

ACTION="${1:-}"
shift 2>/dev/null || true

if [[ "$ACTION" != "run" ]]; then
  exit 1
fi

SKILL_NAME="${1:-}"
shift 2>/dev/null || true

PROFILE="" CONTEXT="" OUTPUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --context) CONTEXT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Check if this skill should succeed
SUCCEED_LIST="__SUCCEED_LIST__"
if [[ "$SUCCEED_LIST" == *"$SKILL_NAME"* ]]; then
  # Find the pre-staged file in the context dir (staged- prefix)
  for f in "$CONTEXT"/staged-"${SKILL_NAME}.yaml"; do
    if [[ -f "$f" ]]; then
      cp "$f" "$OUTPUT"
      echo "$OUTPUT"
      exit 0
    fi
  done
fi

exit 1
INNEREOF

  # Replace placeholder with actual succeed list
  local succeed_str="${succeed_skills[*]+"${succeed_skills[*]}"}"
  sed -i '' "s|__SUCCEED_LIST__|${succeed_str}|" "$mock_script"
  chmod +x "$mock_script"
  echo "$mock_script"
}

echo "=== Rally Plan (Build Card Generation) Tests ==="
echo ""

# --- File existence ---
echo "Files:"
if [[ -f "$PLAN_RUNNER" ]]; then
  echo "  PASS: rally-plan.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: rally-plan.sh missing"
  FAIL=$((FAIL + 1))
fi

if [[ -x "$PLAN_RUNNER" ]]; then
  echo "  PASS: rally-plan.sh is executable"
  PASS=$((PASS + 1))
else
  echo "  FAIL: rally-plan.sh not executable"
  FAIL=$((FAIL + 1))
fi

# --- Input validation ---
echo ""
echo "Input validation:"
assert_exit "no args shows usage and fails" 1 "$PLAN_RUNNER"
assert_exit "nonexistent profile fails" 1 "$PLAN_RUNNER" "/nonexistent/profile.yaml"
assert_exit "help flag succeeds" 0 "$PLAN_RUNNER" --help
assert_contains "help shows usage" "Usage" "$PLAN_RUNNER" --help
assert_contains "help mentions pipeline" "product-manager" "$PLAN_RUNNER" --help

# --- Rally CLI integration ---
echo ""
echo "Rally CLI integration:"
assert_contains "rally help shows plan command" "plan" "$RALLY" help
assert_exit "rally plan without args fails" 1 "$RALLY" plan
assert_exit "rally plan help succeeds" 0 "$RALLY" plan --help

# --- Build card assembly with pre-staged outputs (all skills succeed) ---
echo ""
echo "Build card assembly (mock pipeline — all skills succeed):"

TEST_BUILD_DIR=$(mktemp -d)
TEST_OUTPUT="${TEST_BUILD_DIR}/build-card.yaml"
MOCK_DIR=$(mktemp -d)

# Stage all skill outputs (staged- prefix to avoid colliding with pipeline outputs)
cp "$FIXTURES/pm-output-valid.yaml" "${TEST_BUILD_DIR}/staged-product-manager.yaml"
cp "$FIXTURES/oss-researcher-output-valid.yaml" "${TEST_BUILD_DIR}/staged-oss-researcher.yaml"
cp "$FIXTURES/architect-output-valid.yaml" "${TEST_BUILD_DIR}/staged-architect.yaml"
cp "$FIXTURES/security-output-valid.yaml" "${TEST_BUILD_DIR}/staged-security-auditor.yaml"

MOCK_RUNNER=$(create_mock_runner "$MOCK_DIR" "product-manager" "oss-researcher" "architect" "security-auditor")

set +e
RALLY_SKILL_RUNNER="$MOCK_RUNNER" "$PLAN_RUNNER" "$VALID_PROFILE" \
  --output "$TEST_OUTPUT" --build-dir "$TEST_BUILD_DIR" > /dev/null 2>&1
plan_exit=$?
set -e

if [[ $plan_exit -eq 0 ]]; then
  echo "  PASS: mock plan execution succeeds"
  PASS=$((PASS + 1))
else
  echo "  FAIL: mock plan execution failed (exit $plan_exit)"
  FAIL=$((FAIL + 1))
fi

if [[ -f "$TEST_OUTPUT" ]]; then
  echo "  PASS: build card file created"
  PASS=$((PASS + 1))
else
  echo "  FAIL: build card file not created"
  FAIL=$((FAIL + 1))
fi

# Validate build card structure
assert_file_contains "build card has schema_version" "$TEST_OUTPUT" "^schema_version: 1"
assert_file_contains "build card has generated_at" "$TEST_OUTPUT" "^generated_at:"
assert_file_contains "build card has project_name" "$TEST_OUTPUT" "^project_name:"
assert_file_contains "build card has status" "$TEST_OUTPUT" "^status:"
assert_file_contains "build card has missing_sections" "$TEST_OUTPUT" "^missing_sections:"
assert_file_contains "build card has completed_sections" "$TEST_OUTPUT" "^completed_sections:"
assert_file_contains "build card has product section" "$TEST_OUTPUT" "^product:"
assert_file_contains "build card has oss_analysis section" "$TEST_OUTPUT" "^oss_analysis:"
assert_file_contains "build card has architecture section" "$TEST_OUTPUT" "^architecture:"
assert_file_contains "build card has security_review section" "$TEST_OUTPUT" "^security_review:"
assert_file_contains "all skills complete → status: complete" "$TEST_OUTPUT" "^status: complete"

rm -rf "$TEST_BUILD_DIR" "$MOCK_DIR"

# --- Graceful degradation: some skills fail ---
echo ""
echo "Graceful degradation (some skills fail):"

TEST_BUILD_DIR2=$(mktemp -d)
TEST_OUTPUT2="${TEST_BUILD_DIR2}/build-card.yaml"
MOCK_DIR2=$(mktemp -d)

# Only stage pm and architect
cp "$FIXTURES/pm-output-valid.yaml" "${TEST_BUILD_DIR2}/staged-product-manager.yaml"
cp "$FIXTURES/architect-output-valid.yaml" "${TEST_BUILD_DIR2}/staged-architect.yaml"

MOCK_RUNNER2=$(create_mock_runner "$MOCK_DIR2" "product-manager" "architect")

set +e
RALLY_SKILL_RUNNER="$MOCK_RUNNER2" "$PLAN_RUNNER" "$VALID_PROFILE" \
  --output "$TEST_OUTPUT2" --build-dir "$TEST_BUILD_DIR2" > /dev/null 2>&1
plan_exit2=$?
set -e

if [[ $plan_exit2 -eq 0 ]]; then
  echo "  PASS: plan with missing skills still succeeds"
  PASS=$((PASS + 1))
else
  echo "  FAIL: plan with missing skills should succeed (exit $plan_exit2)"
  FAIL=$((FAIL + 1))
fi

assert_file_contains "partial status when skills fail" "$TEST_OUTPUT2" "^status: partial"
assert_file_contains "product section present" "$TEST_OUTPUT2" "^product:"
assert_file_contains "architecture section present" "$TEST_OUTPUT2" "^architecture:"
assert_file_contains "missing section has not_available" "$TEST_OUTPUT2" "status: not_available"
assert_file_contains "oss_analysis in missing_sections" "$TEST_OUTPUT2" "oss_analysis"
assert_file_contains "security_review in missing_sections" "$TEST_OUTPUT2" "security_review"

rm -rf "$TEST_BUILD_DIR2" "$MOCK_DIR2"

# --- Graceful degradation: all skills fail ---
echo ""
echo "Graceful degradation (all skills fail):"

TEST_BUILD_DIR3=$(mktemp -d)
TEST_OUTPUT3="${TEST_BUILD_DIR3}/build-card.yaml"
MOCK_DIR3=$(mktemp -d)

# No skills succeed
MOCK_RUNNER3=$(create_mock_runner "$MOCK_DIR3")

set +e
RALLY_SKILL_RUNNER="$MOCK_RUNNER3" "$PLAN_RUNNER" "$VALID_PROFILE" \
  --output "$TEST_OUTPUT3" --build-dir "$TEST_BUILD_DIR3" > /dev/null 2>&1
plan_exit3=$?
set -e

if [[ $plan_exit3 -eq 0 ]]; then
  echo "  PASS: plan with all skills failed still produces output"
  PASS=$((PASS + 1))
else
  echo "  FAIL: plan with all skills failed should still produce output (exit $plan_exit3)"
  FAIL=$((FAIL + 1))
fi

if [[ -f "$TEST_OUTPUT3" ]]; then
  assert_file_contains "failed status when all skills fail" "$TEST_OUTPUT3" "^status: failed"
else
  echo "  FAIL: build card not created when all skills fail"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TEST_BUILD_DIR3" "$MOCK_DIR3"

# --- Output path options ---
echo ""
echo "Output path options:"

TEST_BUILD_DIR4=$(mktemp -d)
CUSTOM_OUTPUT="${TEST_BUILD_DIR4}/custom/path/card.yaml"
MOCK_DIR4=$(mktemp -d)

MOCK_RUNNER4=$(create_mock_runner "$MOCK_DIR4")

set +e
RALLY_SKILL_RUNNER="$MOCK_RUNNER4" "$PLAN_RUNNER" "$VALID_PROFILE" \
  --output "$CUSTOM_OUTPUT" --build-dir "$TEST_BUILD_DIR4" > /dev/null 2>&1
set -e

if [[ -f "$CUSTOM_OUTPUT" ]]; then
  echo "  PASS: custom output path works"
  PASS=$((PASS + 1))
else
  echo "  FAIL: custom output path not created"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TEST_BUILD_DIR4" "$MOCK_DIR4"

# --- Read-only verification ---
echo ""
echo "Read-only verification:"

TEST_BUILD_DIR5=$(mktemp -d)
TEST_OUTPUT5="${TEST_BUILD_DIR5}/build-card.yaml"
PROJECT_DIR=$(mktemp -d)
cp "$VALID_PROFILE" "$PROJECT_DIR/profile.yaml"
MOCK_DIR5=$(mktemp -d)

MOCK_RUNNER5=$(create_mock_runner "$MOCK_DIR5")

before_count=$(find "$PROJECT_DIR" -type f | wc -l | tr -d ' ')

set +e
RALLY_SKILL_RUNNER="$MOCK_RUNNER5" "$PLAN_RUNNER" "$PROJECT_DIR/profile.yaml" \
  --output "$TEST_OUTPUT5" --build-dir "$TEST_BUILD_DIR5" > /dev/null 2>&1
set -e

after_count=$(find "$PROJECT_DIR" -type f | wc -l | tr -d ' ')

if [[ "$before_count" == "$after_count" ]]; then
  echo "  PASS: no files created in project directory"
  PASS=$((PASS + 1))
else
  echo "  FAIL: files created in project directory (before=$before_count, after=$after_count)"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TEST_BUILD_DIR5" "$MOCK_DIR5" "$PROJECT_DIR"

# === Results ===
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if (( FAIL > 0 )); then
  exit 1
fi
