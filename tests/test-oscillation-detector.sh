#!/usr/bin/env bash
# test-oscillation-detector.sh - Tests for oscillation detection functionality
#
# Tests the lib/oscillation-detector.sh script

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
echo "Oscillation Detector Tests"
echo "========================================="
echo

# Test 1: Script exists and is executable
if [[ -x "$LIB_DIR/oscillation-detector.sh" ]]; then
    pass "oscillation-detector.sh exists and is executable"
else
    fail "oscillation-detector.sh missing or not executable"
fi

# Test 2: Script shows usage without arguments
if "$LIB_DIR/oscillation-detector.sh" 2>&1 | grep -q "Usage:"; then
    pass "Script shows usage when run without arguments"
else
    fail "Script does not show usage"
fi

# Test 3: Script has watch command
if grep -q 'watch_project' "$LIB_DIR/oscillation-detector.sh"; then
    pass "Script has watch_project function"
else
    fail "watch_project function missing"
fi

# Test 4: Script has analyze command
if grep -q 'analyze_project' "$LIB_DIR/oscillation-detector.sh"; then
    pass "Script has analyze_project function"
else
    fail "analyze_project function missing"
fi

# Test 5: Script has oscillation detection logic
if grep -q 'check_oscillation' "$LIB_DIR/oscillation-detector.sh"; then
    pass "Script has check_oscillation function"
else
    fail "check_oscillation function missing"
fi

# Test 6: Script tracks file hashes
if grep -q 'hash_file' "$LIB_DIR/oscillation-detector.sh"; then
    pass "Script has hash_file function"
else
    fail "hash_file function missing"
fi

# Test 7: Script records state
if grep -q 'record_state' "$LIB_DIR/oscillation-detector.sh"; then
    pass "Script has record_state function"
else
    fail "record_state function missing"
fi

# Test 8: Script detects A-B-A-B patterns
if grep -q 'pattern_detected' "$LIB_DIR/oscillation-detector.sh"; then
    pass "Script has A-B-A-B pattern detection"
else
    fail "A-B-A-B pattern detection missing"
fi

# Test 9: Script can record test output
if grep -q 'record_test_output' "$LIB_DIR/oscillation-detector.sh"; then
    pass "Script has record_test_output function"
else
    fail "record_test_output function missing"
fi

# Test 10: Script has clear command
if grep -q 'clear_state' "$LIB_DIR/oscillation-detector.sh"; then
    pass "Script has clear_state function"
else
    fail "clear_state function missing"
fi

# Test 11: Script uses state directory
if grep -q 'STATE_DIR' "$LIB_DIR/oscillation-detector.sh"; then
    pass "Script uses STATE_DIR for persistence"
else
    fail "STATE_DIR not defined"
fi

# Test 12: Script has configurable threshold
if grep -q 'OSCILLATION_THRESHOLD' "$LIB_DIR/oscillation-detector.sh"; then
    pass "Script has OSCILLATION_THRESHOLD configuration"
else
    fail "OSCILLATION_THRESHOLD not defined"
fi

# Test 13: Script warns about oscillation
if grep -q 'OSCILLATION DETECTED' "$LIB_DIR/oscillation-detector.sh"; then
    pass "Script warns when oscillation is detected"
else
    fail "Oscillation warning message missing"
fi

# Test 14: Script excludes common noise directories
if grep -q 'node_modules\|__pycache__' "$LIB_DIR/oscillation-detector.sh"; then
    pass "Script excludes node_modules and __pycache__"
else
    fail "Noise directory exclusions missing"
fi

echo
echo "========================================="
echo "Oscillation Detector Test Results"
echo "========================================="
echo -e "Total: $TESTS_RUN | ${GREEN}Passed: $TESTS_PASSED${NC} | ${RED}Failed: $TESTS_FAILED${NC}"
echo

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
