#!/usr/bin/env bash
# run-tests.sh - Run all sovereign-agent tests
# Usage: ./tests/run-tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}"
echo "========================================"
echo "  Sovereign Agent Test Suite"
echo "========================================"
echo -e "${NC}"

FAILED_SUITES=()

# Run shell script tests
run_test_suite() {
    local name="$1"
    local script="$2"
    
    echo -e "\n${BLUE}>>> Running: $name${NC}\n"
    
    if bash "$script"; then
        echo -e "\n${GREEN}$name: PASSED${NC}"
    else
        echo -e "\n${RED}$name: FAILED${NC}"
        FAILED_SUITES+=("$name")
    fi
}

# Run oh-my-opencode TypeScript tests
run_omo_tests() {
    local name="oh-my-opencode TypeScript tests"
    
    echo -e "\n${BLUE}>>> Running: $name${NC}\n"
    
    cd "$PROJECT_DIR/vendor/oh-my-opencode"
    
    if bun test 2>&1 | tail -10; then
        echo -e "\n${GREEN}$name: PASSED${NC}"
    else
        echo -e "\n${RED}$name: FAILED${NC}"
        FAILED_SUITES+=("$name")
    fi
    
    cd "$PROJECT_DIR"
}

# Run all test suites
run_test_suite "Validation Tests" "$SCRIPT_DIR/test-validate.sh"
run_test_suite "Config Generation Tests" "$SCRIPT_DIR/test-generate-configs.sh"
run_test_suite "Check Dependencies Tests" "$SCRIPT_DIR/test-check-deps.sh"
run_test_suite "Install Script Tests" "$SCRIPT_DIR/test-install.sh"
run_test_suite "Sync Upstream Tests" "$SCRIPT_DIR/test-sync-upstream.sh"
run_test_suite "Security Features Tests" "$SCRIPT_DIR/test-security-features.sh"
run_test_suite "AGENTS.md Validation Tests" "$SCRIPT_DIR/test-validate-agents-md.sh"
run_test_suite "Network Firewall Tests" "$SCRIPT_DIR/test-network-firewall.sh"
run_test_suite "Budget Firewall Tests" "$SCRIPT_DIR/test-budget-firewall.sh"
run_test_suite "Oscillation Detector Tests" "$SCRIPT_DIR/test-oscillation-detector.sh"
run_test_suite "Plugin Version Pinning Tests" "$SCRIPT_DIR/test-plugin-version-pinning.sh"
run_test_suite "Bash Permissions Tests" "$SCRIPT_DIR/test-bash-permissions.sh"
run_test_suite "DCP Cache Documentation Tests" "$SCRIPT_DIR/test-dcp-cache-documentation.sh"
run_omo_tests

# Summary
echo -e "\n${BOLD}${BLUE}"
echo "========================================"
echo "  Test Summary"
echo "========================================"
echo -e "${NC}"

if [[ ${#FAILED_SUITES[@]} -eq 0 ]]; then
    echo -e "${GREEN}All test suites passed!${NC}"
    exit 0
else
    echo -e "${RED}Failed suites:${NC}"
    for suite in "${FAILED_SUITES[@]}"; do
        echo "  - $suite"
    done
    exit 1
fi
