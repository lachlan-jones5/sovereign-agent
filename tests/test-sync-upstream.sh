#!/usr/bin/env bash
# test-sync-upstream.sh - Test the upstream sync script
# Usage: ./tests/test-sync-upstream.sh

# Don't use set -e as we test various scenarios

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPTS_DIR="$PROJECT_DIR/scripts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

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
    echo "  Expected: $2"
    echo "  Got: $3"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

# Test 1: Script exists and is executable
test_script_exists() {
    local name="sync-upstream.sh exists and is executable"
    if [[ -x "$SCRIPTS_DIR/sync-upstream.sh" ]]; then
        pass "$name"
    else
        fail "$name" "executable script" "missing or not executable"
    fi
}

# Test 2: Help flag works
test_help_flag() {
    local name="--help flag shows usage"
    local output
    output=$("$SCRIPTS_DIR/sync-upstream.sh" --help 2>&1)
    
    if echo "$output" | grep -q "Usage:"; then
        pass "$name"
    else
        fail "$name" "Usage text" "no usage text"
    fi
}

# Test 3: Status command works (should not error)
test_status_command() {
    local name="status command runs without error"
    if "$SCRIPTS_DIR/sync-upstream.sh" status >/dev/null 2>&1; then
        pass "$name"
    else
        fail "$name" "exit code 0" "non-zero exit code"
    fi
}

# Test 4: Status shows both submodules
test_status_shows_submodules() {
    local name="status shows both submodules"
    local output
    output=$("$SCRIPTS_DIR/sync-upstream.sh" status 2>&1)
    
    if echo "$output" | grep -q "opencode" && echo "$output" | grep -q "oh-my-opencode"; then
        pass "$name"
    else
        fail "$name" "both submodules listed" "missing submodule(s)"
    fi
}

# Test 5: Invalid command shows error
test_invalid_command() {
    local name="Invalid command shows error"
    if "$SCRIPTS_DIR/sync-upstream.sh" invalid-command 2>&1 | grep -q "Unknown command"; then
        pass "$name"
    else
        fail "$name" "Unknown command error" "no error message"
    fi
}

# Run all tests
echo "========================================"
echo "Running sync-upstream.sh tests"
echo "========================================"
echo

test_script_exists
test_help_flag
test_status_command
test_status_shows_submodules
test_invalid_command

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
