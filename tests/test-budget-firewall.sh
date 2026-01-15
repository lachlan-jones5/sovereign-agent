#!/usr/bin/env bash
# test-budget-firewall.sh - Tests for budget firewall functionality
#
# Tests the lib/budget-firewall.sh script

# Don't use set -e as we want to run all tests even if some fail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_DIR/lib"

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
echo "Budget Firewall Tests"
echo "========================================="
echo

# Test 1: Script exists and is executable
if [[ -x "$LIB_DIR/budget-firewall.sh" ]]; then
    pass "budget-firewall.sh exists and is executable"
else
    fail "budget-firewall.sh missing or not executable"
fi

# Test 2: Script shows usage without arguments
if "$LIB_DIR/budget-firewall.sh" 2>&1 | grep -q "Usage:"; then
    pass "Script shows usage when run without arguments"
else
    fail "Script does not show usage"
fi

# Test 3: Script defines monthly budget constraint
if grep -q 'MONTHLY_BUDGET_USD=65' "$LIB_DIR/budget-firewall.sh"; then
    pass "Monthly budget USD constraint defined (65)"
else
    fail "Monthly budget USD constraint not defined"
fi

# Test 4: Script defines work budget split (70%)
if grep -q 'WORK_BUDGET_USD=45.50' "$LIB_DIR/budget-firewall.sh"; then
    pass "Work budget split defined (70% = 45.50)"
else
    fail "Work budget split not defined correctly"
fi

# Test 5: Script defines personal budget split (30%)
if grep -q 'PERSONAL_BUDGET_USD=19.50' "$LIB_DIR/budget-firewall.sh"; then
    pass "Personal budget split defined (30% = 19.50)"
else
    fail "Personal budget split not defined correctly"
fi

# Test 6: Model costs include DeepSeek V3
if grep -q 'deepseek/deepseek-v3' "$LIB_DIR/budget-firewall.sh"; then
    pass "Model costs include DeepSeek V3"
else
    fail "DeepSeek V3 not in model costs"
fi

# Test 7: Model costs include Claude Opus
if grep -q 'anthropic/claude-opus' "$LIB_DIR/budget-firewall.sh"; then
    pass "Model costs include Claude Opus"
else
    fail "Claude Opus not in model costs"
fi

# Test 8: Model costs include Gemini Flash
if grep -q 'google/gemini' "$LIB_DIR/budget-firewall.sh"; then
    pass "Model costs include Gemini Flash"
else
    fail "Gemini Flash not in model costs"
fi

# Test 9: Script has status command
if grep -q 'show_status' "$LIB_DIR/budget-firewall.sh"; then
    pass "Script has show_status function"
else
    fail "show_status function missing"
fi

# Test 10: Script has estimate command
if grep -q 'estimate_costs' "$LIB_DIR/budget-firewall.sh"; then
    pass "Script has estimate_costs function"
else
    fail "estimate_costs function missing"
fi

# Test 11: Script has setup-limits command
if grep -q 'setup_limits' "$LIB_DIR/budget-firewall.sh"; then
    pass "Script has setup_limits function"
else
    fail "setup_limits function missing"
fi

# Test 12: Script has monitor command
if grep -q 'monitor_usage' "$LIB_DIR/budget-firewall.sh"; then
    pass "Script has monitor_usage function"
else
    fail "monitor_usage function missing"
fi

# Test 13: Estimate includes Opus cost warning
if grep -q 'WARNING.*Opus' "$LIB_DIR/budget-firewall.sh" || grep -q 'iterations with Opus' "$LIB_DIR/budget-firewall.sh"; then
    pass "Estimate includes Opus cost warning"
else
    fail "Opus cost warning missing"
fi

echo
echo "========================================="
echo "Budget Firewall Test Results"
echo "========================================="
echo -e "Total: $TESTS_RUN | ${GREEN}Passed: $TESTS_PASSED${NC} | ${RED}Failed: $TESTS_FAILED${NC}"
echo

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
