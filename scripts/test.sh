#!/bin/bash
# Run all tests

echo "🧪 Running Rally Tavern Tests"
echo ""

FAILED=0

for test_file in tests/test_*.sh; do
  [[ -f "$test_file" ]] || continue
  echo "Running: $test_file"
  if bash "$test_file"; then
    echo ""
  else
    FAILED=$((FAILED + 1))
  fi
done

echo "===================="
if [[ $FAILED -eq 0 ]]; then
  echo "✓ All tests passed!"
  exit 0
else
  echo "✗ $FAILED test file(s) failed"
  exit 1
fi
