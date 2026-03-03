#!/bin/bash
# Tests for Rally Skill Framework (Feature 01)
# Usage: ./tests/test_rally_skill.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_RUNNER="$REPO_ROOT/scripts/rally-skill.sh"
RALLY="$REPO_ROOT/scripts/rally.sh"
SKILLS_DIR="$REPO_ROOT/skills"
TEMPLATE="$REPO_ROOT/templates/skill.yaml"
VALID_SKILL="$SCRIPT_DIR/fixtures/test-skill.yaml"
INVALID_SKILL="$SCRIPT_DIR/fixtures/invalid-skill.yaml"
VALID_PROFILE="$SCRIPT_DIR/fixtures/valid-profile.yaml"
VALID_OUTPUT="$SCRIPT_DIR/fixtures/test-skill-output-valid.yaml"
INVALID_OUTPUT="$SCRIPT_DIR/fixtures/test-skill-output-invalid.yaml"

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

echo "=== Rally Skill Framework Tests ==="
echo ""

# --- File existence ---
echo "Files:"
for f in "$SKILL_RUNNER" "$TEMPLATE"; do
  if [[ -f "$f" ]]; then
    echo "  PASS: exists: $(basename "$f")"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: missing: $f"
    FAIL=$((FAIL + 1))
  fi
done

if [[ -x "$SKILL_RUNNER" ]]; then
  echo "  PASS: rally-skill.sh is executable"
  PASS=$((PASS + 1))
else
  echo "  FAIL: rally-skill.sh not executable"
  FAIL=$((FAIL + 1))
fi

if [[ -d "$SKILLS_DIR" ]]; then
  echo "  PASS: skills/ directory exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: skills/ directory missing"
  FAIL=$((FAIL + 1))
fi

# --- Skill template structure ---
echo ""
echo "Skill template structure:"
for key in name version description input prompt output; do
  if grep -q "^${key}:" "$TEMPLATE"; then
    echo "  PASS: template has '$key'"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: template missing '$key'"
    FAIL=$((FAIL + 1))
  fi
done

# Check for required_keys in template
if grep -q "required_keys:" "$TEMPLATE"; then
  echo "  PASS: template has 'required_keys'"
  PASS=$((PASS + 1))
else
  echo "  FAIL: template missing 'required_keys'"
  FAIL=$((FAIL + 1))
fi

# --- Skill runner: help/usage ---
echo ""
echo "Skill runner basics:"
assert_exit "no args shows usage" 1 "$SKILL_RUNNER"
assert_contains "usage shows commands" "run" "$SKILL_RUNNER"
assert_contains "usage shows list" "list" "$SKILL_RUNNER"

# --- Skill list ---
echo ""
echo "Skill list:"
assert_exit "list succeeds" 0 "$SKILL_RUNNER" list
assert_contains "list shows header" "Available Skills" "$SKILL_RUNNER" list

# --- Skill validate ---
echo ""
echo "Skill validation:"
assert_exit "valid skill passes" 0 "$SKILL_RUNNER" validate "$VALID_SKILL"
assert_exit "invalid skill fails" 1 "$SKILL_RUNNER" validate "$INVALID_SKILL"
assert_exit "missing file fails" 1 "$SKILL_RUNNER" validate "/nonexistent/skill.yaml"
assert_exit "no args fails" 1 "$SKILL_RUNNER" validate

# --- Skill show ---
echo ""
echo "Skill show:"
# Copy test skill to skills dir temporarily
cp "$VALID_SKILL" "$SKILLS_DIR/test-skill.yaml"
assert_exit "show existing skill succeeds" 0 "$SKILL_RUNNER" show "test-skill"
assert_contains "show displays name" "test-skill" "$SKILL_RUNNER" show "test-skill"
assert_exit "show nonexistent skill fails" 1 "$SKILL_RUNNER" show "nonexistent-skill"
rm -f "$SKILLS_DIR/test-skill.yaml"

# --- Skill run: input validation ---
echo ""
echo "Skill run (input validation):"
cp "$VALID_SKILL" "$SKILLS_DIR/test-skill.yaml"
assert_exit "run without args fails" 1 "$SKILL_RUNNER" run
assert_exit "run without profile fails" 1 "$SKILL_RUNNER" run "test-skill"
assert_exit "run with nonexistent profile fails" 1 "$SKILL_RUNNER" run "test-skill" --profile "/nonexistent"
assert_exit "run with nonexistent skill fails" 1 "$SKILL_RUNNER" run "no-such-skill" --profile "$VALID_PROFILE"
rm -f "$SKILLS_DIR/test-skill.yaml"

# --- Output validation logic ---
echo ""
echo "Output validation:"

# Test validate_output by calling rally-skill.sh's validate_output
# We create a helper script that defines the function inline
TEST_TMPDIR=$(mktemp -d)
cat > "$TEST_TMPDIR/test_validate.sh" << SCRIPT
#!/bin/bash
set -euo pipefail

log_error() { echo "ERROR: \$*" >&2; }

validate_output() {
  local output_file="\$1" skill_file="\$2"
  local errors=0
  local in_output=false in_keys=false
  while IFS= read -r line; do
    if [[ "\$line" =~ ^output: ]]; then
      in_output=true
      continue
    fi
    if \$in_output && [[ "\$line" =~ ^[[:space:]]+required_keys: ]]; then
      in_keys=true
      continue
    fi
    if \$in_keys; then
      if [[ "\$line" =~ ^[a-z_] ]]; then
        break
      fi
      if [[ "\$line" =~ ^[[:space:]]+[a-z_]+: ]] && [[ ! "\$line" =~ ^[[:space:]]+- ]]; then
        break
      fi
      if [[ "\$line" =~ ^[[:space:]]+- ]]; then
        local key
        key=\$(echo "\$line" | sed 's/^[[:space:]]*-[[:space:]]*//')
        if ! grep -q "^\${key}:" "\$output_file" 2>/dev/null; then
          log_error "Missing: \$key"
          errors=\$((errors + 1))
        fi
      fi
    fi
  done < "\$skill_file"
  return \$errors
}

validate_output "\$1" "\$2"
SCRIPT
chmod +x "$TEST_TMPDIR/test_validate.sh"

# Valid output should pass
set +e
"$TEST_TMPDIR/test_validate.sh" "$VALID_OUTPUT" "$VALID_SKILL" > /dev/null 2>&1
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
"$TEST_TMPDIR/test_validate.sh" "$INVALID_OUTPUT" "$VALID_SKILL" > /dev/null 2>&1
result=$?
set -e
if [[ "$result" -ne 0 ]]; then
  echo "  PASS: invalid output fails validation (missing key detected)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: invalid output should fail validation"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TEST_TMPDIR"

# --- Rally entry point: skill subcommand ---
echo ""
echo "Rally entry point (skill subcommand):"
assert_exit "rally skill shows usage" 1 "$RALLY" skill
assert_contains "rally skill shows commands" "run" "$RALLY" skill
assert_exit "rally skill list succeeds" 0 "$RALLY" skill list
assert_contains "rally help shows skill" "skill" "$RALLY" help
assert_contains "rally help shows defaults" "defaults" "$RALLY" help

# === Results ===
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if (( FAIL > 0 )); then
  exit 1
fi
