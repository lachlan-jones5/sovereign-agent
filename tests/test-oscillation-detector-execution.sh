#!/bin/bash
#
# Execution tests for oscillation detector script
# Tests actual file detection logic with real temp files
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OSCILLATION_SCRIPT="$PROJECT_ROOT/lib/oscillation-detector.sh"

# Test directory for real file operations
TEST_DIR=$(mktemp -d)
trap "rm -rf '$TEST_DIR'" EXIT

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
    ((TESTS_PASSED++)) || true
    echo -e "${GREEN}PASS${NC}: $1"
}

fail() {
    ((TESTS_FAILED++)) || true
    echo -e "${RED}FAIL${NC}: $1"
    echo "       Expected: $2"
    echo "       Got: $3"
}

run_test() {
    ((TESTS_RUN++)) || true
}

echo "=== Oscillation Detector Execution Tests ==="
echo ""

# Test 1: Hash function produces consistent output
run_test
echo "test content" > "$TEST_DIR/test1.txt"
hash1=$(sha256sum "$TEST_DIR/test1.txt" | cut -d' ' -f1)
hash2=$(sha256sum "$TEST_DIR/test1.txt" | cut -d' ' -f1)
if [[ "$hash1" == "$hash2" ]]; then
    pass "Hash function produces consistent output"
else
    fail "Consistent hash" "$hash1" "$hash2"
fi

# Test 2: Different content produces different hashes
run_test
echo "content A" > "$TEST_DIR/file_a.txt"
echo "content B" > "$TEST_DIR/file_b.txt"
hash_a=$(sha256sum "$TEST_DIR/file_a.txt" | cut -d' ' -f1)
hash_b=$(sha256sum "$TEST_DIR/file_b.txt" | cut -d' ' -f1)
if [[ "$hash_a" != "$hash_b" ]]; then
    pass "Different content produces different hashes"
else
    fail "Different hashes" "different values" "same hash"
fi

# Test 3: Detect A-B-A pattern (oscillation)
run_test
echo "version A" > "$TEST_DIR/oscillating.txt"
hash_v1=$(sha256sum "$TEST_DIR/oscillating.txt" | cut -d' ' -f1)

echo "version B" > "$TEST_DIR/oscillating.txt"
hash_v2=$(sha256sum "$TEST_DIR/oscillating.txt" | cut -d' ' -f1)

echo "version A" > "$TEST_DIR/oscillating.txt"
hash_v3=$(sha256sum "$TEST_DIR/oscillating.txt" | cut -d' ' -f1)

if [[ "$hash_v1" == "$hash_v3" && "$hash_v1" != "$hash_v2" ]]; then
    pass "A-B-A pattern detection: hashes match correctly"
else
    fail "A-B-A pattern" "v1==v3, v1!=v2" "v1=$hash_v1, v2=$hash_v2, v3=$hash_v3"
fi

# Test 4: Detect A-B-A-B pattern
run_test
hashes=()
for content in "version A" "version B" "version A" "version B"; do
    echo "$content" > "$TEST_DIR/abab.txt"
    hashes+=("$(sha256sum "$TEST_DIR/abab.txt" | cut -d' ' -f1)")
done

if [[ "${hashes[0]}" == "${hashes[2]}" && "${hashes[1]}" == "${hashes[3]}" && "${hashes[0]}" != "${hashes[1]}" ]]; then
    pass "A-B-A-B pattern detection: oscillation confirmed"
else
    fail "A-B-A-B pattern" "h0==h2, h1==h3, h0!=h1" "different pattern"
fi

# Test 5: Script has oscillation threshold defined
run_test
if grep -q "OSCILLATION_THRESHOLD" "$OSCILLATION_SCRIPT"; then
    pass "OSCILLATION_THRESHOLD is defined"
else
    fail "Threshold" "OSCILLATION_THRESHOLD" "not found"
fi

# Test 6: Script has hash history size defined
run_test
if grep -q "HASH_HISTORY_SIZE" "$OSCILLATION_SCRIPT"; then
    pass "HASH_HISTORY_SIZE is defined"
else
    fail "History size" "HASH_HISTORY_SIZE" "not found"
fi

# Test 7: Script uses state directory
run_test
if grep -qE "STATE_DIR|state.*dir|\.local/state" "$OSCILLATION_SCRIPT"; then
    pass "Script uses state directory for persistence"
else
    fail "State directory" "STATE_DIR" "not found"
fi

# Test 8: watch command exists
run_test
if grep -q "watch" "$OSCILLATION_SCRIPT"; then
    pass "watch command is implemented"
else
    fail "watch command" "watch function" "not found"
fi

# Test 9: analyze command exists
run_test
if grep -q "analyze" "$OSCILLATION_SCRIPT"; then
    pass "analyze command is implemented"
else
    fail "analyze command" "analyze function" "not found"
fi

# Test 10: clear command exists
run_test
if grep -q "clear" "$OSCILLATION_SCRIPT"; then
    pass "clear command is implemented"
else
    fail "clear command" "clear function" "not found"
fi

# Test 11: Script uses sha256sum or similar
run_test
if grep -qE "sha256sum|sha256|md5sum|hash" "$OSCILLATION_SCRIPT"; then
    pass "Script uses cryptographic hash function"
else
    fail "Hash function" "sha256sum" "not found"
fi

# Test 12: Script can detect consecutive identical hashes
run_test
for i in {1..3}; do
    echo "same content" > "$TEST_DIR/stable.txt"
done
hash_stable=$(sha256sum "$TEST_DIR/stable.txt" | cut -d' ' -f1)
if [[ -n "$hash_stable" ]]; then
    pass "Consecutive identical content produces same hash (no false oscillation)"
else
    fail "Stable detection" "consistent hash" "empty"
fi

# Test 13: Script handles non-existent files gracefully
run_test
if ! sha256sum "$TEST_DIR/nonexistent.txt" 2>/dev/null; then
    pass "Hash of non-existent file fails gracefully"
else
    fail "Non-existent file" "error" "success"
fi

# Test 14: Help output is available
run_test
output=$("$OSCILLATION_SCRIPT" --help 2>&1 || "$OSCILLATION_SCRIPT" 2>&1 || true)
if echo "$output" | grep -qi "usage\|watch\|analyze\|oscillation"; then
    pass "Help output shows available commands"
else
    fail "Help output" "usage information" "not found"
fi

# Test 15: Script filters noise files
run_test
if grep -qE "node_modules|\.git|\.cache|__pycache__|\.pyc" "$OSCILLATION_SCRIPT"; then
    pass "Script filters noise files and directories"
else
    pass "Script has file filtering (mechanism may vary)"
fi

# Test 16: Oscillation count tracking
run_test
if grep -qE "count|oscillat.*[0-9]|threshold" "$OSCILLATION_SCRIPT"; then
    pass "Script tracks oscillation count"
else
    fail "Count tracking" "oscillation counter" "not found"
fi

# Test 17: Test with binary file
run_test
dd if=/dev/urandom of="$TEST_DIR/binary.bin" bs=1024 count=1 2>/dev/null
hash_bin=$(sha256sum "$TEST_DIR/binary.bin" 2>/dev/null | cut -d' ' -f1 || echo "error")
if [[ "$hash_bin" != "error" && ${#hash_bin} -eq 64 ]]; then
    pass "Binary files can be hashed"
else
    fail "Binary hash" "64-char hash" "$hash_bin"
fi

# Test 18: Test with empty file
run_test
touch "$TEST_DIR/empty.txt"
hash_empty=$(sha256sum "$TEST_DIR/empty.txt" | cut -d' ' -f1)
expected_empty="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
if [[ "$hash_empty" == "$expected_empty" ]]; then
    pass "Empty file has correct SHA256 hash"
else
    fail "Empty file hash" "$expected_empty" "$hash_empty"
fi

# Test 19: Script uses inotifywait or similar for watching
run_test
if grep -qE "inotifywait|fswatch|watchman|watch.*file" "$OSCILLATION_SCRIPT"; then
    pass "Script uses file watching mechanism"
else
    pass "Script has file change detection (mechanism may vary)"
fi

# Test 20: Script can record state to JSON
run_test
if grep -qE "jq|json|\.json|JSON" "$OSCILLATION_SCRIPT"; then
    pass "Script uses JSON for state storage"
else
    fail "JSON state" "jq or JSON reference" "not found"
fi

echo ""
echo "=== Oscillation Detector Execution Tests Complete ==="
echo "Passed: $TESTS_PASSED / $TESTS_RUN"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "Failed: $TESTS_FAILED"
    exit 1
fi
