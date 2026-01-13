#!/usr/bin/env bash
# test-network-firewall.sh - Tests for network firewall functionality
#
# Tests the lib/network-firewall.sh script without requiring root access

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
echo "Network Firewall Tests"
echo "========================================="
echo

# Test 1: Script exists and is executable
if [[ -x "$LIB_DIR/network-firewall.sh" ]]; then
    pass "network-firewall.sh exists and is executable"
else
    fail "network-firewall.sh missing or not executable"
fi

# Test 2: Script shows usage without arguments
if "$LIB_DIR/network-firewall.sh" 2>&1 | grep -q "Usage:"; then
    pass "Script shows usage when run without arguments"
else
    fail "Script does not show usage"
fi

# Test 3: Allowed hosts include openrouter.ai
if grep -q 'openrouter.ai' "$LIB_DIR/network-firewall.sh"; then
    pass "Allowed hosts include openrouter.ai"
else
    fail "openrouter.ai not in allowed hosts"
fi

# Test 4: Allowed hosts include npm registry
if grep -q 'registry.npmjs.org' "$LIB_DIR/network-firewall.sh"; then
    pass "Allowed hosts include npm registry"
else
    fail "npm registry not in allowed hosts"
fi

# Test 5: Allowed hosts include GitHub
if grep -q 'github.com' "$LIB_DIR/network-firewall.sh"; then
    pass "Allowed hosts include github.com"
else
    fail "github.com not in allowed hosts"
fi

# Test 6: Blocked ranges include 10.0.0.0/8
if grep -q '10.0.0.0/8' "$LIB_DIR/network-firewall.sh"; then
    pass "Blocked ranges include 10.0.0.0/8 (Class A private)"
else
    fail "10.0.0.0/8 not in blocked ranges"
fi

# Test 7: Blocked ranges include 172.16.0.0/12
if grep -q '172.16.0.0/12' "$LIB_DIR/network-firewall.sh"; then
    pass "Blocked ranges include 172.16.0.0/12 (Class B private)"
else
    fail "172.16.0.0/12 not in blocked ranges"
fi

# Test 8: Blocked ranges include 192.168.0.0/16
if grep -q '192.168.0.0/16' "$LIB_DIR/network-firewall.sh"; then
    pass "Blocked ranges include 192.168.0.0/16 (Class C private)"
else
    fail "192.168.0.0/16 not in blocked ranges"
fi

# Test 9: Blocked ranges include link-local
if grep -q '169.254.0.0/16' "$LIB_DIR/network-firewall.sh"; then
    pass "Blocked ranges include 169.254.0.0/16 (link-local)"
else
    fail "169.254.0.0/16 not in blocked ranges"
fi

# Test 10: Script has generate command for rules file
if grep -q 'generate_rules_file' "$LIB_DIR/network-firewall.sh"; then
    pass "Script has generate_rules_file function"
else
    fail "generate_rules_file function missing"
fi

# Test 11: Script supports all required commands
required_commands=("apply" "status" "reset" "test" "generate")
all_commands_present=true
for cmd in "${required_commands[@]}"; do
    if ! grep -q "$cmd)" "$LIB_DIR/network-firewall.sh"; then
        all_commands_present=false
        break
    fi
done
if [[ "$all_commands_present" == true ]]; then
    pass "Script supports all required commands (apply/status/reset/test/generate)"
else
    fail "Script missing required commands"
fi

# Test 12: Docker compose has firewall documentation
if grep -q 'ENABLE_NETWORK_FIREWALL' "$PROJECT_DIR/docker-compose.yml"; then
    pass "Docker compose includes ENABLE_NETWORK_FIREWALL variable"
else
    fail "Docker compose missing ENABLE_NETWORK_FIREWALL variable"
fi

# Test 13: Docker compose documents iron box network isolation
if grep -q 'Iron Box' "$PROJECT_DIR/docker-compose.yml"; then
    pass "Docker compose documents Iron Box network isolation"
else
    fail "Docker compose missing Iron Box documentation"
fi

# Test 14: Allowed hosts include pypi for Python packages
if grep -q 'pypi.org' "$LIB_DIR/network-firewall.sh"; then
    pass "Allowed hosts include pypi.org"
else
    fail "pypi.org not in allowed hosts"
fi

echo
echo "========================================="
echo "Network Firewall Test Results"
echo "========================================="
echo -e "Total: $TESTS_RUN | ${GREEN}Passed: $TESTS_PASSED${NC} | ${RED}Failed: $TESTS_FAILED${NC}"
echo

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
