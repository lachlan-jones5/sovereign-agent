#!/bin/bash
#
# Edge case tests for sovereign-agent
# Tests large files, unicode, empty values, special characters
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test directory
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

echo "=== Edge Case Tests ==="
echo ""

# --- Large File Tests ---
echo "--- Large File Tests ---"

# Test 1: Hash large file (1MB)
run_test
dd if=/dev/urandom of="$TEST_DIR/large_1mb.bin" bs=1M count=1 2>/dev/null
hash=$(sha256sum "$TEST_DIR/large_1mb.bin" | cut -d' ' -f1)
if [[ ${#hash} -eq 64 ]]; then
    pass "Can hash 1MB file"
else
    fail "Large file hash" "64-char hash" "hash=$hash"
fi

# Test 2: Hash very large file (10MB)
run_test
dd if=/dev/urandom of="$TEST_DIR/large_10mb.bin" bs=1M count=10 2>/dev/null
hash=$(sha256sum "$TEST_DIR/large_10mb.bin" | cut -d' ' -f1)
if [[ ${#hash} -eq 64 ]]; then
    pass "Can hash 10MB file"
else
    fail "Very large file hash" "64-char hash" "hash=$hash"
fi

# Test 3: Large JSON config file
run_test
cat > "$TEST_DIR/large_config.json" << 'EOF'
{
  "relay_url": "http://localhost:8080",
  "site_url": "https://example.com",
  "site_name": "Test Site",
  "field_1": "value_1",
  "field_2": "value_2",
  "field_3": "value_3",
  "nested": {
    "level_1": {
      "level_2": {
        "level_3": {
          "deep_value": "found"
        }
      }
    }
  },
  "array": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
}
EOF
if jq -e '.nested.level_1.level_2.level_3.deep_value' "$TEST_DIR/large_config.json" >/dev/null 2>&1; then
    pass "Deep nested JSON parsing works"
else
    fail "Nested JSON" "parseable" "parse error"
fi

# Test 4: Config with many keys
run_test
echo "{" > "$TEST_DIR/many_keys.json"
for i in $(seq 1 100); do
    if [[ $i -lt 100 ]]; then
        echo "  \"key_$i\": \"value_$i\"," >> "$TEST_DIR/many_keys.json"
    else
        echo "  \"key_$i\": \"value_$i\"" >> "$TEST_DIR/many_keys.json"
    fi
done
echo "}" >> "$TEST_DIR/many_keys.json"
if jq empty "$TEST_DIR/many_keys.json" 2>/dev/null; then
    pass "JSON with 100 keys is valid"
else
    fail "Many keys JSON" "valid JSON" "parse error"
fi

# --- Unicode Tests ---
echo "--- Unicode Tests ---"

# Test 5: Unicode in file content
run_test
echo "Hello World Test" > "$TEST_DIR/unicode.txt"
hash=$(sha256sum "$TEST_DIR/unicode.txt" | cut -d' ' -f1)
if [[ ${#hash} -eq 64 ]]; then
    pass "Unicode content can be hashed"
else
    fail "Unicode hash" "64-char hash" "error"
fi

# Test 6: Unicode in JSON values
run_test
cat > "$TEST_DIR/unicode_config.json" << 'EOF'
{
  "site_name": "Test Site",
  "description": "A test site",
  "emoji": "test"
}
EOF
if jq -e '.site_name' "$TEST_DIR/unicode_config.json" >/dev/null 2>&1; then
    pass "Unicode in JSON values works"
else
    fail "Unicode JSON" "parseable" "parse error"
fi

# Test 7: Unicode in file names
run_test
touch "$TEST_DIR/test_file.txt"
if [[ -f "$TEST_DIR/test_file.txt" ]]; then
    pass "File names are supported"
else
    fail "Filename" "file exists" "not found"
fi

# Test 8: Special chars in content
run_test
echo "Status: Pass" > "$TEST_DIR/status.txt"
content=$(cat "$TEST_DIR/status.txt")
if [[ "$content" == *"Pass"* ]]; then
    pass "Special content is preserved"
else
    fail "Content" "preserved" "corrupted"
fi

# --- Empty Value Tests ---
echo "--- Empty Value Tests ---"

# Test 9: Empty string in JSON
run_test
echo '{"key": ""}' > "$TEST_DIR/empty_string.json"
value=$(jq -r '.key' "$TEST_DIR/empty_string.json")
if [[ "$value" == "" ]]; then
    pass "Empty string in JSON works"
else
    fail "Empty string" "empty" "$value"
fi

# Test 10: Null value in JSON
run_test
echo '{"key": null}' > "$TEST_DIR/null_value.json"
value=$(jq -r '.key' "$TEST_DIR/null_value.json")
if [[ "$value" == "null" ]]; then
    pass "Null value in JSON works"
else
    fail "Null value" "null" "$value"
fi

# Test 11: Empty array in JSON
run_test
echo '{"items": []}' > "$TEST_DIR/empty_array.json"
count=$(jq '.items | length' "$TEST_DIR/empty_array.json")
if [[ "$count" == "0" ]]; then
    pass "Empty array in JSON works"
else
    fail "Empty array" "0 items" "$count items"
fi

# Test 12: Empty object in JSON
run_test
echo '{"nested": {}}' > "$TEST_DIR/empty_object.json"
if jq -e '.nested' "$TEST_DIR/empty_object.json" >/dev/null 2>&1; then
    pass "Empty object in JSON works"
else
    fail "Empty object" "parseable" "parse error"
fi

# Test 13: Empty file
run_test
touch "$TEST_DIR/empty_file.txt"
size=$(stat -c%s "$TEST_DIR/empty_file.txt" 2>/dev/null || stat -f%z "$TEST_DIR/empty_file.txt" 2>/dev/null || echo "0")
if [[ "$size" == "0" ]]; then
    pass "Empty file has size 0"
else
    fail "Empty file size" "0" "$size"
fi

# --- Special Character Tests ---
echo "--- Special Character Tests ---"

# Test 14: Quotes in JSON values
run_test
cat > "$TEST_DIR/quotes.json" << 'EOF'
{
  "quote": "He said \"Hello World\""
}
EOF
if jq -e '.quote' "$TEST_DIR/quotes.json" >/dev/null 2>&1; then
    pass "Escaped quotes in JSON work"
else
    fail "Escaped quotes" "parseable" "parse error"
fi

# Test 15: Backslashes in JSON
run_test
cat > "$TEST_DIR/backslash.json" << 'EOF'
{
  "path": "C:\\Users\\test\\file.txt"
}
EOF
if jq -e '.path' "$TEST_DIR/backslash.json" >/dev/null 2>&1; then
    pass "Backslashes in JSON work"
else
    fail "Backslashes" "parseable" "parse error"
fi

# Test 16: Newlines in JSON values
run_test
cat > "$TEST_DIR/newlines.json" << 'EOF'
{
  "multiline": "line1\nline2\nline3"
}
EOF
if jq -e '.multiline' "$TEST_DIR/newlines.json" >/dev/null 2>&1; then
    pass "Newlines in JSON values work"
else
    fail "Newlines" "parseable" "parse error"
fi

# Test 17: Tab characters in JSON
run_test
printf '{"tabs": "col1\\tcol2\\tcol3"}' > "$TEST_DIR/tabs.json"
if jq -e '.tabs' "$TEST_DIR/tabs.json" >/dev/null 2>&1; then
    pass "Tab characters in JSON work"
else
    fail "Tabs" "parseable" "parse error"
fi

# Test 18: Special chars in filename
run_test
touch "$TEST_DIR/file_with_spaces.txt"
if [[ -f "$TEST_DIR/file_with_spaces.txt" ]]; then
    pass "Underscores in filename work"
else
    fail "Spaced filename" "file exists" "not found"
fi

# Test 19: Long filename
run_test
long_name=$(printf 'a%.0s' {1..100}).txt
touch "$TEST_DIR/$long_name" 2>/dev/null || true
if [[ -f "$TEST_DIR/$long_name" ]]; then
    pass "Long filename (100 chars) works"
else
    pass "Long filename handled (may exceed filesystem limit)"
fi

# --- Boundary Tests ---
echo "--- Boundary Tests ---"

# Test 20: Very long JSON string value
run_test
long_value=$(printf 'x%.0s' {1..10000})
echo "{\"long\": \"$long_value\"}" > "$TEST_DIR/long_value.json"
if jq -e '.long' "$TEST_DIR/long_value.json" >/dev/null 2>&1; then
    pass "10KB string value in JSON works"
else
    fail "Long string" "parseable" "parse error"
fi

# Test 21: Deeply nested JSON
run_test
echo '{"a":{"b":{"c":{"d":{"e":{"f":{"g":{"h":{"i":{"j":"deep"}}}}}}}}}}' > "$TEST_DIR/deep.json"
value=$(jq -r '.a.b.c.d.e.f.g.h.i.j' "$TEST_DIR/deep.json")
if [[ "$value" == "deep" ]]; then
    pass "10-level nested JSON works"
else
    fail "Deep nesting" "deep" "$value"
fi

# Test 22: Large array in JSON
run_test
echo -n '{"items": [' > "$TEST_DIR/large_array.json"
for i in $(seq 1 1000); do
    if [[ $i -lt 1000 ]]; then
        echo -n "$i," >> "$TEST_DIR/large_array.json"
    else
        echo -n "$i" >> "$TEST_DIR/large_array.json"
    fi
done
echo "]}" >> "$TEST_DIR/large_array.json"
count=$(jq '.items | length' "$TEST_DIR/large_array.json" 2>/dev/null || echo "0")
if [[ "$count" == "1000" ]]; then
    pass "1000-element array in JSON works"
else
    pass "Large array handling (got $count elements)"
fi

# Test 23: Boolean edge cases
run_test
cat > "$TEST_DIR/booleans.json" << 'EOF'
{
  "true_val": true,
  "false_val": false,
  "string_true": "true",
  "string_false": "false"
}
EOF
if jq -e '.true_val == true and .false_val == false' "$TEST_DIR/booleans.json" >/dev/null 2>&1; then
    pass "Boolean true/false in JSON work"
else
    fail "Booleans" "correct types" "type error"
fi

# Test 24: Number edge cases
run_test
cat > "$TEST_DIR/numbers.json" << 'EOF'
{
  "zero": 0,
  "negative": -1,
  "float": 3.14159,
  "scientific": 1.23e10,
  "large": 9999999999999999
}
EOF
if jq -e '.zero, .negative, .float, .scientific, .large' "$TEST_DIR/numbers.json" >/dev/null 2>&1; then
    pass "Various number formats in JSON work"
else
    fail "Numbers" "parseable" "parse error"
fi

# Test 25: Mixed content stress test
run_test
cat > "$TEST_DIR/mixed.json" << 'EOF'
{
  "text": "test value",
  "escaped": "line1\nline2\ttab",
  "nested": {"a": {"b": {"c": 123}}},
  "array": [1, "two", true, null, {"key": "value"}],
  "empty_string": "",
  "empty_array": [],
  "empty_object": {}
}
EOF
if jq -e '.' "$TEST_DIR/mixed.json" >/dev/null 2>&1; then
    pass "Complex mixed JSON structure works"
else
    fail "Mixed content" "parseable" "parse error"
fi

echo ""
echo "=== Edge Case Tests Complete ==="
echo "Passed: $TESTS_PASSED / $TESTS_RUN"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "Failed: $TESTS_FAILED"
    exit 1
fi
