#!/bin/bash
# Test knowledge snapshot generation and validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

PASSED=0
FAILED=0

pass() { echo "  ✓ $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  ✗ $1"; FAILED=$((FAILED + 1)); }

echo "📸 Testing knowledge snapshot"

# --- Test 1: Snapshot generation produces valid JSON ---
echo ""
echo "Test: Snapshot generates valid JSON"
OUTPUT=$(bash scripts/knowledge-snapshot.sh 2>/dev/null)
if echo "$OUTPUT" | python3 -m json.tool > /dev/null 2>&1; then
  pass "Valid JSON output"
else
  fail "Invalid JSON output"
fi

# --- Test 2: Snapshot contains required metadata fields ---
echo ""
echo "Test: Snapshot metadata fields"
if echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['version']==1" 2>/dev/null; then
  pass "version field present and equals 1"
else
  fail "version field missing or wrong"
fi

if echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'generated_at' in d" 2>/dev/null; then
  pass "generated_at field present"
else
  fail "generated_at field missing"
fi

if echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert len(d['source_hash'])==64" 2>/dev/null; then
  pass "source_hash is SHA-256 (64 chars)"
else
  fail "source_hash missing or wrong length"
fi

if echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['entry_count']==len(d['entries'])" 2>/dev/null; then
  pass "entry_count matches actual entries length"
else
  fail "entry_count doesn't match entries length"
fi

# --- Test 3: Entries have required fields ---
echo ""
echo "Test: Entry structure"
if echo "$OUTPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for e in d['entries']:
    assert 'id' in e, f'missing id in {e.get(\"title\",\"?\")}'
    assert 'kind' in e, f'missing kind in {e[\"id\"]}'
    assert 'title' in e, f'missing title in {e[\"id\"]}'
    assert 'tags' in e, f'missing tags in {e[\"id\"]}'
    assert isinstance(e['tags'], list), f'tags not a list in {e[\"id\"]}'
" 2>/dev/null; then
  pass "All entries have required fields (id, kind, title, tags)"
else
  fail "Some entries missing required fields"
fi

if echo "$OUTPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
kinds = {e['kind'] for e in d['entries']}
assert 'practice' in kinds, 'no practice entries'
" 2>/dev/null; then
  pass "Contains practice entries"
else
  fail "No practice entries found"
fi

# --- Test 4: No deprecated entries in snapshot ---
echo ""
echo "Test: Deprecated entries excluded"
if echo "$OUTPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for e in d['entries']:
    assert not e.get('deprecated', False), f'{e[\"id\"]} is deprecated but in snapshot'
" 2>/dev/null; then
  pass "No deprecated entries in snapshot"
else
  fail "Deprecated entries found in snapshot"
fi

# --- Test 5: Snapshot --check works after generation ---
echo ""
echo "Test: Snapshot freshness check"
bash scripts/knowledge-snapshot.sh --output /tmp/test-snapshot.json 2>/dev/null
if bash scripts/knowledge-snapshot.sh --check --output /tmp/test-snapshot.json 2>/dev/null; then
  pass "Freshly generated snapshot passes --check"
else
  fail "Fresh snapshot fails --check"
fi
rm -f /tmp/test-snapshot.json

# --- Test 6: Snapshot --check detects stale snapshot ---
echo ""
echo "Test: Stale snapshot detection"
# Create a snapshot with a bad hash
echo '{"version":1,"source_hash":"0000000000000000000000000000000000000000000000000000000000000000","entry_count":0,"entries":[]}' > /tmp/test-stale-snapshot.json
if ! bash scripts/knowledge-snapshot.sh --check --output /tmp/test-stale-snapshot.json 2>/dev/null; then
  pass "Stale snapshot correctly detected"
else
  fail "Stale snapshot not detected"
fi
rm -f /tmp/test-stale-snapshot.json

# --- Test 7: Entry count is reasonable ---
echo ""
echo "Test: Entry count sanity"
ENTRY_COUNT=$(echo "$OUTPUT" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_count'])" 2>/dev/null)
if [[ "$ENTRY_COUNT" -gt 0 ]]; then
  pass "Snapshot contains $ENTRY_COUNT entries (> 0)"
else
  fail "Snapshot has 0 entries"
fi

# --- Summary ---
echo ""
echo "===================="
echo "Passed: $PASSED  Failed: $FAILED"
if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
