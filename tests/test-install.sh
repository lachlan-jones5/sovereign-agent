#!/usr/bin/env bash
# test-install.sh - Test the main installer script
# Usage: ./tests/test-install.sh

# Don't use set -e as we test various scenarios

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_TMP_DIR=$(mktemp -d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

cleanup() {
    rm -rf "$TEST_TMP_DIR"
}
trap cleanup EXIT

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    echo "  Expected: $2"
    echo "  Got: $3"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

# Test 1: install.sh exists and is executable
test_install_exists() {
    local name="install.sh exists and is executable"
    if [[ -x "$PROJECT_DIR/install.sh" ]]; then
        pass "$name"
    else
        fail "$name" "executable script" "missing or not executable"
    fi
}

# Test 2: --help flag shows usage
test_help_flag() {
    local name="--help flag shows usage"
    local output
    output=$("$PROJECT_DIR/install.sh" --help 2>&1)
    
    if echo "$output" | grep -q "Usage:"; then
        pass "$name"
    else
        fail "$name" "Usage text" "no usage text"
    fi
}

# Test 3: -h flag shows usage
test_short_help_flag() {
    local name="-h flag shows usage"
    local output
    output=$("$PROJECT_DIR/install.sh" -h 2>&1)
    
    if echo "$output" | grep -q "Usage:"; then
        pass "$name"
    else
        fail "$name" "Usage text" "no usage text"
    fi
}

# Test 4: Invalid option shows error
test_invalid_option() {
    local name="Invalid option shows error"
    local output
    output=$("$PROJECT_DIR/install.sh" --invalid-option 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -q -i "unknown"; then
        pass "$name"
    else
        fail "$name" "error for unknown option" "$output"
    fi
}

# Test 5: --skip-deps flag is recognized
test_skip_deps_flag() {
    local name="--skip-deps flag is recognized"
    
    local output
    output=$("$PROJECT_DIR/install.sh" --skip-deps 2>&1)
    
    if echo "$output" | grep -q -i "skip"; then
        pass "$name"
    else
        fail "$name" "skip message in output" "no skip message found"
    fi
}

# Test 6: -s flag is recognized (short form of --skip-deps)
test_short_skip_deps_flag() {
    local name="-s flag is recognized"
    
    local output
    output=$("$PROJECT_DIR/install.sh" -s 2>&1)
    
    if echo "$output" | grep -q -i "skip"; then
        pass "$name"
    else
        fail "$name" "skip message in output" "no skip message found"
    fi
}

# Test 7: Banner is printed
test_banner_printed() {
    local name="Banner is printed"
    
    local output
    output=$("$PROJECT_DIR/install.sh" --skip-deps 2>&1)
    
    if echo "$output" | grep -q "Sovereign Agent"; then
        pass "$name"
    else
        fail "$name" "Sovereign Agent in banner" "banner not found"
    fi
}

# Test 8: Script mentions GitHub Copilot
test_github_copilot_mentioned() {
    local name="Script mentions GitHub Copilot"
    
    local output
    output=$("$PROJECT_DIR/install.sh" --skip-deps 2>&1)
    
    if echo "$output" | grep -q -i "github copilot"; then
        pass "$name"
    else
        fail "$name" "GitHub Copilot mention" "not found"
    fi
}

# Test 9: Script indicates OpenCode installation
test_opencode_installation() {
    local name="Script indicates OpenCode installation"
    
    local output
    output=$("$PROJECT_DIR/install.sh" --skip-deps 2>&1)
    
    if echo "$output" | grep -q -i "opencode"; then
        pass "$name"
    else
        fail "$name" "OpenCode mention" "not found"
    fi
}

# Test 10: Script indicates agent setup
test_agent_setup() {
    local name="Script indicates agent setup"
    
    local output
    output=$("$PROJECT_DIR/install.sh" --skip-deps 2>&1)
    
    if echo "$output" | grep -q -i "agent"; then
        pass "$name"
    else
        fail "$name" "agent mention" "not found"
    fi
}

# Run all tests
echo "========================================"
echo "Running install.sh tests"
echo "========================================"
echo

test_install_exists
test_help_flag
test_short_help_flag
test_invalid_option
test_skip_deps_flag
test_short_skip_deps_flag
test_banner_printed
test_github_copilot_mentioned
test_opencode_installation
test_agent_setup

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
