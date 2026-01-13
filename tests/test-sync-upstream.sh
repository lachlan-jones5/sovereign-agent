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

# Test 6: Status shows commit information
test_status_shows_commits() {
    local name="status shows commit information"
    local output
    output=$("$SCRIPTS_DIR/sync-upstream.sh" status 2>&1)
    
    if echo "$output" | grep -q "Commit:"; then
        pass "$name"
    else
        fail "$name" "Commit: in output" "no commit info"
    fi
}

# Test 7: Status shows upstream remote
test_status_shows_upstream() {
    local name="status shows upstream remote"
    local output
    output=$("$SCRIPTS_DIR/sync-upstream.sh" status 2>&1)
    
    if echo "$output" | grep -q "Upstream:"; then
        pass "$name"
    else
        fail "$name" "Upstream: in output" "no upstream info"
    fi
}

# Test 8: Status shows ahead/behind count
test_status_shows_ahead_behind() {
    local name="status shows ahead/behind count"
    local output
    output=$("$SCRIPTS_DIR/sync-upstream.sh" status 2>&1)
    
    if echo "$output" | grep -q "ahead.*behind\|behind.*ahead"; then
        pass "$name"
    else
        fail "$name" "ahead/behind count" "no ahead/behind info"
    fi
}

# Test 9: opencode command is recognized
test_opencode_command() {
    local name="opencode command is recognized (dry run check)"
    local output
    # This will attempt to sync but we're just checking if the command is recognized
    # It may fail if there are uncommitted changes, but should not say "Unknown command"
    output=$("$SCRIPTS_DIR/sync-upstream.sh" opencode 2>&1) || true
    
    if echo "$output" | grep -q -i "Unknown command"; then
        fail "$name" "command recognized" "Unknown command"
    else
        pass "$name"
    fi
}

# Test 10: oh-my-opencode command is recognized
test_omo_command() {
    local name="oh-my-opencode command is recognized (dry run check)"
    local output
    output=$("$SCRIPTS_DIR/sync-upstream.sh" oh-my-opencode 2>&1) || true
    
    if echo "$output" | grep -q -i "Unknown command"; then
        fail "$name" "command recognized" "Unknown command"
    else
        pass "$name"
    fi
}

# Test 11: all command is recognized
test_all_command() {
    local name="all command is recognized (dry run check)"
    local output
    output=$("$SCRIPTS_DIR/sync-upstream.sh" all 2>&1) || true
    
    if echo "$output" | grep -q -i "Unknown command"; then
        fail "$name" "command recognized" "Unknown command"
    else
        pass "$name"
    fi
}

# Test 12: --branch flag is accepted
test_branch_flag() {
    local name="--branch flag is accepted"
    local output
    output=$("$SCRIPTS_DIR/sync-upstream.sh" status --branch main 2>&1)
    
    # Should not error about unknown flag
    if echo "$output" | grep -q -i "unknown.*branch\|invalid.*branch"; then
        fail "$name" "branch flag accepted" "flag rejected"
    else
        pass "$name"
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
test_status_shows_commits
test_status_shows_upstream
test_status_shows_ahead_behind
test_opencode_command
test_omo_command
test_all_command
test_branch_flag

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
