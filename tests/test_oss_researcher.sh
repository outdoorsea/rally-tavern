#!/bin/bash
# Tests for OSS Researcher Skill (Feature 05)
# Usage: ./tests/test_oss_researcher.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_RUNNER="$REPO_ROOT/scripts/rally-skill.sh"
SKILL_FILE="$REPO_ROOT/skills/oss-researcher.yaml"
VALID_PROFILE="$SCRIPT_DIR/fixtures/valid-profile.yaml"
VALID_OUTPUT="$SCRIPT_DIR/fixtures/oss-researcher-output-valid.yaml"
INVALID_OUTPUT="$SCRIPT_DIR/fixtures/oss-researcher-output-invalid.yaml"

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

  if grep -q "$pattern" "$file" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (pattern '$pattern' not found in $file)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== OSS Researcher Skill Tests ==="
echo ""

# --- Skill file exists ---
echo "Skill file:"
if [[ -f "$SKILL_FILE" ]]; then
  echo "  PASS: oss-researcher.yaml exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: oss-researcher.yaml missing"
  FAIL=$((FAIL + 1))
fi

# --- Skill validation ---
echo ""
echo "Skill validation:"
assert_exit "oss-researcher.yaml passes validation" 0 "$SKILL_RUNNER" validate "$SKILL_FILE"

# --- Required schema fields ---
echo ""
echo "Schema fields:"
for key in name version description input prompt output; do
  assert_file_contains "has '$key' field" "$SKILL_FILE" "^${key}:"
done

# --- Skill metadata ---
echo ""
echo "Metadata:"
assert_file_contains "name is oss-researcher" "$SKILL_FILE" "^name: oss-researcher"
assert_file_contains "version is 1" "$SKILL_FILE" "^version: 1"
assert_file_contains "has description" "$SKILL_FILE" "^description:"

# --- Web search tag ---
echo ""
echo "Capability tags:"
assert_file_contains "has tags section" "$SKILL_FILE" "^tags:"
assert_file_contains "has web-search tag" "$SKILL_FILE" "web-search"

# --- Input section ---
echo ""
echo "Input specification:"
assert_file_contains "requires project-profile" "$SKILL_FILE" "project-profile"

# --- Prompt section ---
echo ""
echo "Prompt content:"
assert_file_contains "system prompt defines role" "$SKILL_FILE" "open-source"
assert_file_contains "system prompt mentions license" "$SKILL_FILE" "license"
assert_file_contains "system prompt mentions maturity" "$SKILL_FILE" "maturity"
assert_file_contains "user prompt references profile" "$SKILL_FILE" "{{project-profile}}"
assert_file_contains "user prompt references context" "$SKILL_FILE" "{{context}}"

# --- Output required keys ---
echo ""
echo "Output required keys:"
for key in analysis_date project_name candidates license_summary recommendations; do
  assert_file_contains "requires '$key' output key" "$SKILL_FILE" "[[:space:]]*- $key"
done

# --- Skill appears in list ---
echo ""
echo "Integration:"
assert_contains "appears in skill list" "oss-researcher" "$SKILL_RUNNER" list
assert_exit "show command works" 0 "$SKILL_RUNNER" show "oss-researcher"

# --- Output validation with fixtures ---
echo ""
echo "Output validation:"

# Use inline validate_output from rally-skill.sh
TEST_TMPDIR=$(mktemp -d)
cat > "$TEST_TMPDIR/test_validate.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail
log_error() { echo "ERROR: $*" >&2; }
validate_output() {
  local output_file="$1" skill_file="$2"
  local errors=0
  local in_output=false in_keys=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^output: ]]; then
      in_output=true
      continue
    fi
    if $in_output && [[ "$line" =~ ^[[:space:]]+required_keys: ]]; then
      in_keys=true
      continue
    fi
    if $in_keys; then
      if [[ "$line" =~ ^[a-z_] ]]; then break; fi
      if [[ "$line" =~ ^[[:space:]]+[a-z_]+: ]] && [[ ! "$line" =~ ^[[:space:]]+- ]]; then break; fi
      if [[ "$line" =~ ^[[:space:]]+- ]]; then
        local key
        key=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')
        if ! grep -q "^${key}:" "$output_file" 2>/dev/null; then
          log_error "Missing: $key"
          errors=$((errors + 1))
        fi
      fi
    fi
  done < "$skill_file"
  return $errors
}
validate_output "$1" "$2"
SCRIPT
chmod +x "$TEST_TMPDIR/test_validate.sh"

# Valid output should pass
set +e
"$TEST_TMPDIR/test_validate.sh" "$VALID_OUTPUT" "$SKILL_FILE" > /dev/null 2>&1
result=$?
set -e
if [[ "$result" -eq 0 ]]; then
  echo "  PASS: valid output passes validation"
  PASS=$((PASS + 1))
else
  echo "  FAIL: valid output should pass validation (exit=$result)"
  FAIL=$((FAIL + 1))
fi

# Invalid output should fail
set +e
"$TEST_TMPDIR/test_validate.sh" "$INVALID_OUTPUT" "$SKILL_FILE" > /dev/null 2>&1
result=$?
set -e
if [[ "$result" -ne 0 ]]; then
  echo "  PASS: invalid output fails validation (missing keys detected)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: invalid output should fail validation"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TEST_TMPDIR"

# --- Run input validation ---
echo ""
echo "Run command validation:"
assert_exit "run without profile fails" 1 "$SKILL_RUNNER" run "oss-researcher"
assert_exit "run with nonexistent profile fails" 1 "$SKILL_RUNNER" run "oss-researcher" --profile "/nonexistent"

# === Results ===
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if (( FAIL > 0 )); then
  exit 1
fi
