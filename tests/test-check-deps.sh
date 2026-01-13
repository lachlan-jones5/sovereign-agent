#!/usr/bin/env bash
# test-check-deps.sh - Test the dependency checking script
# Usage: ./tests/test-check-deps.sh

# Don't use set -e as we test various scenarios

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_DIR/lib"
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

# Source the check-deps script
source "$LIB_DIR/check-deps.sh"

# Test 1: command_exists returns true for existing command
test_command_exists_true() {
    local name="command_exists returns true for 'bash'"
    if command_exists bash; then
        pass "$name"
    else
        fail "$name" "true" "false"
    fi
}

# Test 2: command_exists returns false for non-existing command
test_command_exists_false() {
    local name="command_exists returns false for 'nonexistent_command_xyz'"
    if command_exists nonexistent_command_xyz; then
        fail "$name" "false" "true"
    else
        pass "$name"
    fi
}

# Test 3: check_curl succeeds when curl is installed
test_check_curl_installed() {
    local name="check_curl succeeds when curl is installed"
    if command_exists curl; then
        if check_curl >/dev/null 2>&1; then
            pass "$name"
        else
            fail "$name" "success" "failure"
        fi
    else
        echo "SKIP: $name (curl not installed)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

# Test 4: check_jq succeeds when jq is installed
test_check_jq_installed() {
    local name="check_jq succeeds when jq is installed"
    if command_exists jq; then
        if check_jq >/dev/null 2>&1; then
            pass "$name"
        else
            fail "$name" "success" "failure"
        fi
    else
        echo "SKIP: $name (jq not installed)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

# Test 5: check_go succeeds when go is installed
test_check_go_installed() {
    local name="check_go succeeds when go is installed"
    if command_exists go; then
        if check_go >/dev/null 2>&1; then
            pass "$name"
        else
            fail "$name" "success" "failure"
        fi
    else
        echo "SKIP: $name (go not installed)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

# Test 6: check_bun succeeds when bun is installed
test_check_bun_installed() {
    local name="check_bun succeeds when bun is installed"
    # Ensure bun is in PATH
    if [[ -d "$HOME/.bun/bin" ]]; then
        export PATH="$HOME/.bun/bin:$PATH"
    fi
    
    if command_exists bun; then
        if check_bun >/dev/null 2>&1; then
            pass "$name"
        else
            fail "$name" "success" "failure"
        fi
    else
        echo "SKIP: $name (bun not installed)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

# Test 7: log_info outputs correct format
test_log_info_format() {
    local name="log_info outputs correct format"
    local output
    output=$(log_info "test message" 2>&1)
    
    if echo "$output" | grep -q "INFO.*test message"; then
        pass "$name"
    else
        fail "$name" "[INFO] test message" "$output"
    fi
}

# Test 8: log_warn outputs correct format
test_log_warn_format() {
    local name="log_warn outputs correct format"
    local output
    output=$(log_warn "warning message" 2>&1)
    
    if echo "$output" | grep -q "WARN.*warning message"; then
        pass "$name"
    else
        fail "$name" "[WARN] warning message" "$output"
    fi
}

# Test 9: log_error outputs correct format
test_log_error_format() {
    local name="log_error outputs correct format"
    local output
    output=$(log_error "error message" 2>&1)
    
    if echo "$output" | grep -q "ERROR.*error message"; then
        pass "$name"
    else
        fail "$name" "[ERROR] error message" "$output"
    fi
}

# Test 10: VENDOR_DIR is correctly set
test_vendor_dir_set() {
    local name="VENDOR_DIR is correctly set"
    if [[ -n "$VENDOR_DIR" && -d "$VENDOR_DIR" ]]; then
        pass "$name"
    else
        fail "$name" "non-empty directory path" "$VENDOR_DIR"
    fi
}

# Test 11: PROJECT_DIR is correctly set
test_project_dir_set() {
    local name="PROJECT_DIR is correctly set"
    if [[ -n "$PROJECT_DIR" && -d "$PROJECT_DIR" ]]; then
        pass "$name"
    else
        fail "$name" "non-empty directory path" "$PROJECT_DIR"
    fi
}

# Test 12: build_opencode checks for submodule
test_build_opencode_checks_submodule() {
    local name="build_opencode checks for submodule existence"
    
    # Temporarily override VENDOR_DIR to non-existent path
    local original_vendor="$VENDOR_DIR"
    VENDOR_DIR="/nonexistent/path"
    
    local output
    output=$(build_opencode 2>&1)
    local exit_code=$?
    
    VENDOR_DIR="$original_vendor"
    
    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -q -i "submodule"; then
        pass "$name"
    else
        fail "$name" "error about submodule" "$output"
    fi
}

# Test 13: build_oh_my_opencode checks for submodule
test_build_omo_checks_submodule() {
    local name="build_oh_my_opencode checks for submodule existence"
    
    # Temporarily override VENDOR_DIR to non-existent path
    local original_vendor="$VENDOR_DIR"
    VENDOR_DIR="/nonexistent/path"
    
    local output
    output=$(build_oh_my_opencode 2>&1)
    local exit_code=$?
    
    VENDOR_DIR="$original_vendor"
    
    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -q -i "submodule"; then
        pass "$name"
    else
        fail "$name" "error about submodule" "$output"
    fi
}

# Run all tests
echo "========================================"
echo "Running check-deps.sh tests"
echo "========================================"
echo

test_command_exists_true
test_command_exists_false
test_check_curl_installed
test_check_jq_installed
test_check_go_installed
test_check_bun_installed
test_log_info_format
test_log_warn_format
test_log_error_format
test_vendor_dir_set
test_project_dir_set
test_build_opencode_checks_submodule
test_build_omo_checks_submodule

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
