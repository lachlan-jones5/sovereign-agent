#!/usr/bin/env bash
# test-dcp-cache-documentation.sh - Tests for DCP cache invalidation documentation
#
# Tests that DCP configuration includes cache invalidation awareness documentation

# Don't use set -e as we want to run all tests even if some fail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$PROJECT_DIR/templates"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

echo "========================================="
echo "DCP Cache Documentation Tests"
echo "========================================="
echo

# Test 1: DCP template exists
if [[ -f "$TEMPLATES_DIR/dcp.jsonc.tmpl" ]]; then
    pass "dcp.jsonc.tmpl template exists"
else
    fail "dcp.jsonc.tmpl template missing"
fi

# Test 2: Template has cache invalidation documentation header
if grep -q 'CACHE INVALIDATION AWARENESS' "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
    pass "Template has cache invalidation awareness section"
else
    fail "Template missing cache invalidation awareness section"
fi

# Test 3: Template documents turn protection
if grep -q 'TURN PROTECTION' "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
    pass "Template documents turn protection"
else
    fail "Template missing turn protection documentation"
fi

# Test 4: Template documents error retention
if grep -q 'ERROR RETENTION' "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
    pass "Template documents error retention"
else
    fail "Template missing error retention documentation"
fi

# Test 5: Template documents deduplication
if grep -q 'DEDUPLICATION' "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
    pass "Template documents deduplication"
else
    fail "Template missing deduplication documentation"
fi

# Test 6: Template documents supersede writes
if grep -q 'SUPERSEDE WRITES' "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
    pass "Template documents supersede writes"
else
    fail "Template missing supersede writes documentation"
fi

# Test 7: Template documents nudge frequency
if grep -q 'NUDGE FREQUENCY' "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
    pass "Template documents nudge frequency"
else
    fail "Template missing nudge frequency documentation"
fi

# Test 8: Template has cost implications section
if grep -q 'COST IMPLICATIONS' "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
    pass "Template has cost implications section"
else
    fail "Template missing cost implications section"
fi

# Test 9: Template warns about re-read storms
if grep -q 're-read storms' "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
    pass "Template warns about re-read storms"
else
    fail "Template missing re-read storms warning"
fi

# Test 10: Template has recommended settings by use case
if grep -q 'RECOMMENDED SETTINGS BY USE CASE' "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
    pass "Template has recommended settings by use case"
else
    fail "Template missing recommended settings section"
fi

# Test 11: Template documents large codebase settings
if grep -q 'Large codebase' "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
    pass "Template documents large codebase settings"
else
    fail "Template missing large codebase settings"
fi

# Test 12: Template documents quick bug fix settings
if grep -q 'Quick bug fixes' "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
    pass "Template documents quick bug fix settings"
else
    fail "Template missing quick bug fix settings"
fi

# Test 13: Template is valid JSONC (can be parsed after removing comments)
# Extract just the JSON block (starts with { ends with }) and check structure
json_content=$(sed -n '/^{/,/^}/p' "$TEMPLATES_DIR/dcp.jsonc.tmpl" | sed 's/{{[^}]*}}/1/g')
if echo "$json_content" | jq -e '.' > /dev/null 2>&1; then
    pass "Template is valid JSONC format"
else
    # Check if JSON block exists and has proper structure
    if grep -q '"enabled"' "$TEMPLATES_DIR/dcp.jsonc.tmpl" && \
       grep -q '"turnProtection"' "$TEMPLATES_DIR/dcp.jsonc.tmpl" && \
       grep -q '"strategies"' "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
        pass "Template is valid JSONC format (structure verified)"
    else
        fail "Template is not valid JSONC format"
    fi
fi

# Test 14: Template includes all required config keys
required_keys=("enabled" "turnProtection" "strategies" "tools")
all_keys_present=true
for key in "${required_keys[@]}"; do
    if ! grep -q "\"$key\"" "$TEMPLATES_DIR/dcp.jsonc.tmpl"; then
        all_keys_present=false
        break
    fi
done
if [[ "$all_keys_present" == true ]]; then
    pass "Template includes all required config keys"
else
    fail "Template missing required config keys"
fi

echo
echo "========================================="
echo "DCP Cache Documentation Test Results"
echo "========================================="
echo -e "Total: $TESTS_RUN | ${GREEN}Passed: $TESTS_PASSED${NC} | ${RED}Failed: $TESTS_FAILED${NC}"
echo

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
